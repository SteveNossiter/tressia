-- Supabase Database Schema for Tressia
-- ==========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop old tables if they exist to prevent schema conflicts
DROP TABLE IF EXISTS public.sessions CASCADE;
DROP TABLE IF EXISTS public.subtasks CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.invites CASCADE;

-- 1. USERS PROFILE 
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'Therapist', -- 'Administrator', 'Therapist', 'Admin'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Admins can update users" ON public.users FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin'))
);

-- 2. INVITES
CREATE TABLE IF NOT EXISTS public.invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Only admins can manage invites" ON public.invites FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin'))
);

-- 3. PROJECTS (Corresponds to 'Project' model - Client + Phase)
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    client_id TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    client_type TEXT,
    assigned_therapist_ids UUID[] DEFAULT '{}',
    notes TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Access control for projects" ON public.projects FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin')) OR
    auth.uid() = ANY(assigned_therapist_ids)
);

-- 4. TASKS (Corresponds to 'ProjectTask' model)
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    assigned_user_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Access control for tasks" ON public.tasks FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin')) OR
    auth.uid() = ANY(assigned_user_ids)
);

-- 5. SUBTASKS 
CREATE TABLE IF NOT EXISTS public.subtasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    assigned_user_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.subtasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Access control for subtasks" ON public.subtasks FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin')) OR
    auth.uid() = ANY(assigned_user_ids)
);

-- 6. SESSIONS
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id TEXT NOT NULL,
    therapist_ids UUID[] DEFAULT '{}',
    date TIMESTAMPTZ NOT NULL,
    duration_minutes INT DEFAULT 60,
    type TEXT,
    status TEXT DEFAULT 'scheduled',
    general_mood TEXT,
    general_discussion TEXT,
    therapist_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Access control for sessions" ON public.sessions FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('Administrator', 'Admin')) OR
    auth.uid() = ANY(therapist_ids)
);

-- TRIGGERS FOR MODIFIED COLUMN
CREATE OR REPLACE FUNCTION update_modified_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ language 'plpgsql';

CREATE TRIGGER update_projects_modtime BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_tasks_modtime BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_subtasks_modtime BEFORE UPDATE ON public.subtasks FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_sessions_modtime BEFORE UPDATE ON public.sessions FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- TRIGGER FOR NEW USER SIGNUP (INVITE SYSTEM)
-- Note: You MUST pass 'full_name' in the metadata during Auth.signUp()
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
    invite_role TEXT;
    user_count INT;
BEGIN
    SELECT count(*) INTO user_count FROM public.users;
    
    IF user_count = 0 THEN
        -- First user is automatically Administrator
        INSERT INTO public.users (id, full_name, role)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Admin User'), 'Administrator');
    ELSE
        -- Subsequent users must have an invite
        SELECT role INTO invite_role FROM public.invites WHERE email = NEW.email;
        IF invite_role IS NOT NULL THEN
            INSERT INTO public.users (id, full_name, role)
            VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'), invite_role);
            DELETE FROM public.invites WHERE email = NEW.email;
        ELSE
            -- Block signup if no invite
            RAISE EXCEPTION 'You must be invited to join this clinic.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists to prevent errors on re-run
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
