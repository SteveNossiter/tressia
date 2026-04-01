-- Updated Supabase Database Schema for Tressia with Multi-tenancy
-- ==========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop old tables if they exist to prevent schema conflicts
DROP TABLE IF EXISTS public.assignment_requests CASCADE;
DROP TABLE IF EXISTS public.sessions CASCADE;
DROP TABLE IF EXISTS public.subtasks CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.invites CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.clinics CASCADE;

-- 0. CLINICS (Organizations)
CREATE TABLE public.clinics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL DEFAULT 'New Clinic',
    description TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    logo TEXT, -- base64 logo image
    setup_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

-- 1. USERS PROFILE 
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'Therapist', -- 'Administrator', 'Therapist', 'Admin'
    email TEXT,
    phone TEXT,
    address TEXT,
    photo TEXT, -- base64 profile photo
    user_color TEXT, -- hex color string e.g. '#ff9c27b0'
    ahpra_number TEXT,
    qualifications TEXT,
    notes TEXT,
    setup_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. INVITES
CREATE TABLE IF NOT EXISTS public.invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL,
    full_name TEXT DEFAULT 'New Member',
    action_link TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(clinic_id, email)
);
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

-- 3. PROJECTS
CREATE TABLE public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    client_id TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    client_type TEXT,
    assigned_therapist_ids UUID[] DEFAULT '{}',
    client_code TEXT,
    date_of_birth DATE,
    address TEXT,
    phone TEXT,
    email TEXT,
    ndis_number TEXT,
    contacts JSONB DEFAULT '[]',
    notes TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    color TEXT, -- hex color string
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- 4. TASKS
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    assigned_user_ids UUID[] DEFAULT '{}',
    color TEXT, -- hex color string
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- 5. SUBTASKS 
CREATE TABLE public.subtasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'todo',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    assigned_user_ids UUID[] DEFAULT '{}',
    color TEXT, -- hex color string
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.subtasks ENABLE ROW LEVEL SECURITY;

-- 6. SESSIONS
CREATE TABLE public.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
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

-- 7. ASSIGNMENT REQUESTS
CREATE TABLE public.assignment_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES public.users(id),
    to_user_id UUID REFERENCES public.users(id),
    entity_type TEXT,
    entity_id UUID,
    entity_title TEXT,
    message TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.assignment_requests ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- MIGRATION: Add missing columns to projects for demographics
-- -----------------------------------------------------------------------------
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS client_code TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS ndis_number TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS contacts JSONB DEFAULT '[]';

-- Helper function to bypass RLS on self-referencing policies
CREATE OR REPLACE FUNCTION public.get_my_clinic_id()
RETURNS UUID AS $$
  SELECT clinic_id FROM public.users WHERE id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Clinics: Users can see their own clinic
CREATE POLICY "Users can view their clinic" ON public.clinics FOR SELECT 
USING (id = public.get_my_clinic_id());

-- Clinics: Admins can update their own clinic
CREATE POLICY "Admins can update their clinic" ON public.clinics FOR UPDATE 
USING (id = public.get_my_clinic_id());

-- Users: Can read own record
CREATE POLICY "Users can read own record" ON public.users FOR SELECT 
USING (id = auth.uid());

-- Users: Can see users in their own clinic
CREATE POLICY "Users can view clinic members" ON public.users FOR SELECT 
USING (clinic_id = public.get_my_clinic_id());

-- Users: Can update their own record
CREATE POLICY "Users can update own record" ON public.users FOR UPDATE 
USING (id = auth.uid());

-- Projects: Filter by clinic_id AND assigned_therapist_ids (for therapists)
DROP POLICY IF EXISTS "Clinic isolation for projects" ON public.projects;
CREATE POLICY "Clinic isolation for projects" ON public.projects FOR ALL 
USING (
  clinic_id = public.get_my_clinic_id() 
  AND (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'administrator', 'receptionist')
    OR auth.uid()::text = ANY(assigned_therapist_ids)
  )
);

-- Tasks: Restricted to projects the user can see
DROP POLICY IF EXISTS "Clinic isolation for tasks" ON public.tasks;
CREATE POLICY "Clinic isolation for tasks" ON public.tasks FOR ALL 
USING (
  clinic_id = public.get_my_clinic_id()
  AND (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'administrator', 'receptionist')
    OR project_id IN (SELECT id FROM public.projects)
  )
);

-- Subtasks: Restricted to tasks the user can see
DROP POLICY IF EXISTS "Clinic isolation for subtasks" ON public.subtasks;
CREATE POLICY "Clinic isolation for subtasks" ON public.subtasks FOR ALL 
USING (
  clinic_id = public.get_my_clinic_id()
  AND (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'administrator', 'receptionist')
    OR task_id IN (SELECT id FROM public.tasks)
  )
);

-- Sessions: Restricted to projects the user can see
DROP POLICY IF EXISTS "Clinic isolation for sessions" ON public.sessions;
CREATE POLICY "Clinic isolation for sessions" ON public.sessions FOR ALL 
USING (
  clinic_id = public.get_my_clinic_id()
  AND (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'administrator', 'receptionist')
    OR project_id IN (SELECT id FROM public.projects)
  )
);

DROP POLICY IF EXISTS "Clinic isolation for invites" ON public.invites;
CREATE POLICY "Clinic isolation for invites" ON public.invites FOR ALL 
USING (clinic_id = public.get_my_clinic_id());

DROP POLICY IF EXISTS "Clinic isolation for assignment_requests" ON public.assignment_requests;
CREATE POLICY "Clinic isolation for assignment_requests" ON public.assignment_requests FOR ALL 
USING (clinic_id = public.get_my_clinic_id());



-- TRIGGERS FOR MODIFIED COLUMN --
CREATE OR REPLACE FUNCTION update_modified_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ language 'plpgsql';

CREATE TRIGGER update_clinics_modtime BEFORE UPDATE ON public.clinics FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_users_modtime BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_projects_modtime BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_tasks_modtime BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_subtasks_modtime BEFORE UPDATE ON public.subtasks FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_sessions_modtime BEFORE UPDATE ON public.sessions FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- TRIGGER FOR NEW USER SIGNUP / RE-INVITE --
CREATE OR REPLACE FUNCTION public.handle_auth_user_change() 
RETURNS TRIGGER AS $$
DECLARE
    target_clinic_id UUID;
    invite_exists BOOLEAN;
BEGIN
    -- We only act if this user has organically completed their login handshake
    IF NEW.last_sign_in_at IS NULL THEN
        RETURN NEW;
    END IF;

    -- Check if user already exists in public.users to avoid double entry
    IF EXISTS (SELECT 1 FROM public.users WHERE id = NEW.id) THEN
        RETURN NEW;
    END IF;

    -- Is this new user an Invitee? If yes, gracefully do absolutely NO database manipulation!
    -- The customized Flutter Edge Function securely and asynchronously handles migrating Invites.
    SELECT EXISTS(SELECT 1 FROM public.invites WHERE email = NEW.email) INTO invite_exists;
    IF invite_exists THEN
        RETURN NEW;
    END IF;

    -- If this is NOT an Invitee, it's an authentic external Administrator signing up manually.
    -- Build their brand new standalone instance dynamically.
    INSERT INTO public.clinics (name) VALUES ('New Clinic')
    RETURNING id INTO target_clinic_id;

    INSERT INTO public.users (id, clinic_id, full_name, role, setup_complete)
    VALUES (
      NEW.id, 
      target_clinic_id, 
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'Administrator'), 
      'administrator',
      TRUE
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach triggers for both Insert (signups) and Update (confirmations)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_auth_user_change();

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE OF email_confirmed_at, last_sign_in_at ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_auth_user_change();
