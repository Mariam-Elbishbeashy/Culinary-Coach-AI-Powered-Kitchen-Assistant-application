import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _email = '';

  // Core Cooking Preferences
  String _cookingLevel = 'Beginner';
  String _favoriteCuisine = 'Not set';
  String _dietaryPreference = 'None';
  String _allergies = 'None';
  String _spiceTolerance = 'Mild';

  // Practical Cooking Settings
  String _availableCookingTime = '30 min';
  String _servingSizePreference = '1 person';
  String _kitchenEquipment = 'Not set';
  String _budgetPreference = 'Medium';

  // Nutrition Goals
  String _nutritionGoal = 'Healthy eating';

  final _kitchenEquipmentController = TextEditingController();
  final _allergiesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _kitchenEquipmentController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    Map<String, dynamic>? resolved = widget.initialData;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      resolved = doc.data() ?? resolved;
    } catch (_) {
      // keep initial fallback
    }

    _hydrateFromData(resolved);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _hydrateFromData(Map<String, dynamic>? data) {
    final user = FirebaseAuth.instance.currentUser;

    String readString(String key, String fallback) {
      final raw = data?[key];
      if (raw is String) {
        final v = raw.trim();
        if (v.isNotEmpty) return v;
      }
      return fallback;
    }

    _firstNameController.text = readString('firstName', '');
    _lastNameController.text = readString('lastName', '');
    final resolvedEmail = readString('email', (user?.email ?? '').trim());
    _email = resolvedEmail;

    _cookingLevel = readString('cookingLevel', 'Beginner');
    _favoriteCuisine = readString('favoriteCuisine', 'Not set');
    _dietaryPreference = readString('dietaryPreference', 'None');
    _spiceTolerance = readString('spiceTolerance', 'Mild');

    final allergiesValue = _resolveAllergies(data?['allergies']) ?? 'None';
    _allergies = allergiesValue;

    _availableCookingTime = readString('availableCookingTime', '30 min');
    _servingSizePreference = readString('servingSizePreference', '1 person');
    _kitchenEquipment = readString('kitchenEquipment', 'Not set');
    _budgetPreference = readString('budgetPreference', 'Medium');

    _nutritionGoal = readString('nutritionGoal', 'Healthy eating');

    _kitchenEquipmentController.text =
        _kitchenEquipment == 'Not set' ? '' : _kitchenEquipment;
    _allergiesController.text = _allergies == 'None' ? '' : _allergies;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not signed in.')),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter first name and last name.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final equipment = _kitchenEquipmentController.text.trim();
      final allergies = _allergiesController.text.trim();

      final payload = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'cookingLevel': _cookingLevel,
        'favoriteCuisine': _favoriteCuisine,
        'dietaryPreference': _dietaryPreference,
        'allergies': allergies.isEmpty ? 'None' : allergies,
        'spiceTolerance': _spiceTolerance,
        'availableCookingTime': _availableCookingTime,
        'servingSizePreference': _servingSizePreference,
        'kitchenEquipment': equipment.isEmpty ? 'Not set' : equipment,
        'budgetPreference': _budgetPreference,
        'nutritionGoal': _nutritionGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      // Helps the UI pick up the new name quickly in places
      // that rely on FirebaseAuth displayName.
      final displayName = '$firstName $lastName'.trim();
      try {
        if (displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
      } catch (_) {
        // Non-blocking: Firestore is source of truth for Profile.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save changes. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  _SectionCard(
                    title: 'Personal Information',
                    child: Column(
                      children: [
                        _TextRow(
                          label: 'First Name',
                          controller: _firstNameController,
                          hintText: 'First name',
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 10),
                        _TextRow(
                          label: 'Last Name',
                          controller: _lastNameController,
                          hintText: 'Last name',
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 10),
                        _ReadOnlyRow(
                          label: 'Email',
                          value: _email.isEmpty ? 'Not available' : _email,
                          icon: Icons.email_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Core Cooking Preferences',
                    child: Column(
                      children: [
                        _DropdownRow(
                          label: 'Cooking Level',
                          value: _cookingLevel,
                          items: const [
                            'Beginner',
                            'Intermediate',
                            'Advanced',
                          ],
                          onChanged: (v) => setState(() => _cookingLevel = v),
                          icon: Icons.emoji_events_rounded,
                        ),
                        const SizedBox(height: 10),
                        _DropdownRow(
                          label: 'Favorite Cuisine',
                          value: _favoriteCuisine,
                          items: const [
                            'Not set',
                            'Italian',
                            'Asian',
                            'Middle Eastern',
                            'Indian',
                            'Mexican',
                            'American',
                            'Mediterranean',
                            'Other',
                          ],
                          onChanged: (v) => setState(() => _favoriteCuisine = v),
                          icon: Icons.public_rounded,
                        ),
                        const SizedBox(height: 10),
                        _DropdownRow(
                          label: 'Dietary Preference',
                          value: _dietaryPreference,
                          items: const [
                            'None',
                            'Vegetarian',
                            'Vegan',
                            'Keto',
                            'Low carb',
                            'Gluten-free',
                            'Dairy-free',
                            'Halal',
                            'Other',
                          ],
                          onChanged: (v) =>
                              setState(() => _dietaryPreference = v),
                          icon: Icons.eco_rounded,
                        ),
                        const SizedBox(height: 10),
                        _TextRow(
                          label: 'Allergies',
                          controller: _allergiesController,
                          hintText: 'None',
                          icon: Icons.health_and_safety_rounded,
                        ),
                        const SizedBox(height: 10),
                        _DropdownRow(
                          label: 'Spice Tolerance',
                          value: _spiceTolerance,
                          items: const ['Mild', 'Medium', 'Hot'],
                          onChanged: (v) =>
                              setState(() => _spiceTolerance = v),
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Practical Cooking Settings',
                    child: Column(
                      children: [
                        _DropdownRow(
                          label: 'Available Cooking Time',
                          value: _availableCookingTime,
                          items: const ['15 min', '30 min', '45 min', '60+ min'],
                          onChanged: (v) =>
                              setState(() => _availableCookingTime = v),
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(height: 10),
                        _DropdownRow(
                          label: 'Serving Size Preference',
                          value: _servingSizePreference,
                          items: const [
                            '1 person',
                            '2 people',
                            '3-4 people',
                            '5+ people',
                          ],
                          onChanged: (v) =>
                              setState(() => _servingSizePreference = v),
                          icon: Icons.groups_rounded,
                        ),
                        const SizedBox(height: 10),
                        _TextRow(
                          label: 'Kitchen Equipment',
                          controller: _kitchenEquipmentController,
                          hintText: 'Not set',
                          icon: Icons.kitchen_rounded,
                        ),
                        const SizedBox(height: 10),
                        _DropdownRow(
                          label: 'Budget Preference',
                          value: _budgetPreference,
                          items: const ['Low', 'Medium', 'High'],
                          onChanged: (v) =>
                              setState(() => _budgetPreference = v),
                          icon: Icons.payments_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Nutrition Goals',
                    child: Column(
                      children: [
                        _DropdownRow(
                          label: 'Nutrition Goal',
                          value: _nutritionGoal,
                          items: const [
                            'Healthy eating',
                            'Weight loss',
                            'Muscle gain',
                            'High protein',
                            'Low sugar',
                            'Other',
                          ],
                          onChanged: (v) => setState(() => _nutritionGoal = v),
                          icon: Icons.monitor_heart_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String? _resolveAllergies(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      return value;
    }
    if (raw is List) {
      final parts = raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              cursorColor: AppColors.primaryDeep,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Icon(icon, color: AppColors.primaryDeep, size: 18),
    );
  }
}

