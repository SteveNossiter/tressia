import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_module.dart';
import '../providers/app_state.dart';
import '../widgets/dialogs/glass_dialog.dart';
import 'client_profile_screen.dart';

class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({Key? key}) : super(key: key);

  @override
  _ProvidersScreenState createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  ProviderType? _filterType;
  String _searchQuery = '';

  static const Map<ProviderType, Color> _typeColors = {
    ProviderType.ndis: Colors.blue,
    ProviderType.medicare: Colors.green,
    ProviderType.referrer: Colors.teal,
    ProviderType.specialist: Colors.purple,
    ProviderType.other: Colors.grey,
  };

  static const Map<ProviderType, IconData> _typeIcons = {
    ProviderType.ndis: Icons.verified,
    ProviderType.medicare: Icons.local_hospital,
    ProviderType.referrer: Icons.send,
    ProviderType.specialist: Icons.medical_services,
    ProviderType.other: Icons.business,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = ref.watch(providersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final projects = ref.watch(projectsProvider);
    final isAdmin = currentUser.isAdmin;

    var filtered = providers.where((p) {
      final matchesType = _filterType == null || p.type == _filterType;
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.contactName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Providers',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search providers...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  // Filter chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _filterChip('All', null, theme),
                        ...ProviderType.values.map(
                          (t) => _filterChip(t.name.toUpperCase(), t, theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_business),
                  tooltip: 'Add Provider',
                  onPressed: () => _showProviderDialog(context, null),
                ),
            ],
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 48,
                      color: theme.hintColor.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No providers found',
                      style: GoogleFonts.outfit(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildProviderCard(
                    context,
                    filtered[i],
                    projects,
                    theme,
                    isAdmin,
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ProviderType? type, ThemeData theme) {
    final isSelected = _filterType == type;
    final color = type != null
        ? (_typeColors[type] ?? Colors.grey)
        : theme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.outfit(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) =>
            setState(() => _filterType = isSelected ? null : type),
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        side: BorderSide(color: isSelected ? color : Colors.transparent),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    NdisProvider provider,
    List<Project> projects,
    ThemeData theme,
    bool isAdmin,
  ) {
    final typeColor = _typeColors[provider.type] ?? Colors.grey;
    final typeIcon = _typeIcons[provider.type] ?? Icons.business;
    final linkedClients = projects
        .where((p) => provider.associatedClientIds.contains(p.id))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showProviderDetail(context, provider, linkedClients),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.businessName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (provider.contactName.isNotEmpty)
                          Text(
                            provider.contactName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      provider.type.name.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (provider.phone.isNotEmpty || provider.email.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (provider.phone.isNotEmpty) ...[
                      const Icon(Icons.phone, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        provider.phone,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (provider.email.isNotEmpty) ...[
                      const Icon(
                        Icons.email_outlined,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (linkedClients.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: linkedClients
                      .map(
                        (c) => InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClientProfileScreen(clientProject: c),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.clientCode.isNotEmpty
                                  ? c.clientCode
                                  : c.clientName,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderDetail(
    BuildContext context,
    NdisProvider provider,
    List<Project> linkedClients,
  ) {
    final theme = Theme.of(context);
    final typeColor = _typeColors[provider.type] ?? Colors.grey;
    final isAdmin = ref.read(currentUserProvider).isAdmin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.businessName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.edit, color: theme.primaryColor),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showProviderDialog(context, provider);
                        },
                      ),
                  ],
                ),
                Text(
                  provider.type.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (provider.contactName.isNotEmpty)
                  _detailRow(
                    Icons.person,
                    'Contact',
                    provider.contactName,
                    theme,
                  ),
                if (provider.phone.isNotEmpty)
                  _detailRow(Icons.phone, 'Phone', provider.phone, theme),
                if (provider.email.isNotEmpty)
                  _detailRow(
                    Icons.email_outlined,
                    'Email',
                    provider.email,
                    theme,
                  ),
                if (provider.address.isNotEmpty)
                  _detailRow(
                    Icons.location_on_outlined,
                    'Address',
                    provider.address,
                    theme,
                  ),
                if (provider.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notes',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: theme.hintColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      provider.notes,
                      style: GoogleFonts.outfit(height: 1.5),
                    ),
                  ),
                ],
                if (linkedClients.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Associated Clients',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...linkedClients.map(
                    (c) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          c.firstName.isNotEmpty ? c.firstName[0] : '?',
                          style: GoogleFonts.outfit(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        c.clientName,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${c.clientCode}  •  ${c.clientType}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: theme.hintColor,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClientProfileScreen(clientProject: c),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, color: theme.hintColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );

  void _showProviderDialog(BuildContext context, NdisProvider? existing) {
    final nameCtrl = TextEditingController(text: existing?.businessName ?? '');
    final contactCtrl = TextEditingController(
      text: existing?.contactName ?? '',
    );
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    ProviderType type = existing?.type ?? ProviderType.ndis;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Text(
            existing == null ? 'Add Provider' : 'Edit Provider',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ProviderType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Provider Type'),
                  items: ProviderType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDState(() => type = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business Name *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  ref
                      .read(providersProvider.notifier)
                      .removeProvider(existing.id);
                  Navigator.pop(dCtx);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                if (existing == null) {
                  ref
                      .read(providersProvider.notifier)
                      .addProvider(
                        NdisProvider(
                          businessName: nameCtrl.text.trim(),
                          type: type,
                          contactName: contactCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        ),
                      );
                } else {
                  ref
                      .read(providersProvider.notifier)
                      .updateProvider(
                        existing.copyWith(
                          businessName: nameCtrl.text.trim(),
                          type: type,
                          contactName: contactCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        ),
                      );
                }
                Navigator.pop(dCtx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
