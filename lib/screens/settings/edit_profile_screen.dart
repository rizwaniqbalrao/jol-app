import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../auth/models/user.dart';
import 'services/user_profile_services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ══════════════════════════════════════════════════════════════
  // Colors
  // ══════════════════════════════════════════════════════════════
  static const Color textPink = Color(0xFFF82A87);
  static const Color accentPurple = Color(0xFF9B4BFF);
  static const Color textGreen = Color(0xFF4CAF50);

  // ══════════════════════════════════════════════════════════════
  // Services & Controllers
  // ══════════════════════════════════════════════════════════════
  final UserProfileService _profileService = UserProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // ══════════════════════════════════════════════════════════════
  // State
  // ══════════════════════════════════════════════════════════════
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  User? _user;
  UserProfile? _profile;
  DateTime? _selectedBirthDate;
  String? _avatarUrl;
  File? _selectedAvatarFile;
  bool _avatarChanged = false;

  // Form validation
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // Data Loading
  // ══════════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load both user and profile data
    final userResult = await _profileService.getUserDetail();
    final profileResult = await _profileService.getUserProfile();

    if (userResult.success && userResult.user != null) {
      setState(() {
        _user = userResult.user;
        _profile = profileResult.profile;

        // Populate controllers
        _firstNameController.text = _user?.firstName ?? '';
        _lastNameController.text = _user?.lastName ?? '';
        _usernameController.text = _user?.username ?? '';
        _emailController.text = _user?.email ?? '';
        _bioController.text = _profile?.bio ?? '';
        _locationController.text = _profile?.location ?? '';
        _selectedBirthDate = _profile?.birthDate;
        _avatarUrl = _profile?.avatar;

        _isLoading = false;
      });
    } else {
      setState(() {
        _error = userResult.error ?? 'Failed to load profile data';
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Image Picker
  // ══════════════════════════════════════════════════════════════
  Future<void> _pickAvatar() async {
    if (_isLoading) return;

    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: textPink),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: textPink),
                  title: const Text('Take a Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedAvatarFile = File(pickedFile.path);
          _avatarChanged = true;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Save Profile
  // ══════════════════════════════════════════════════════════════
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final userResult = await _profileService.patchUserDetail(
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim().isEmpty
            ? null
            : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
      );

      if (!userResult.success) {
        setState(() {
          _error = userResult.error ?? 'Failed to update user details';
          _isSaving = false;
        });
        return;
      }

      ProfileResult profileResult;

      if (_avatarChanged && _selectedAvatarFile != null) {
        profileResult = await _profileService.patchUserProfileWithAvatar(
          avatar: _selectedAvatarFile,
          bio: _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          birthDate: _selectedBirthDate,
        );
      } else {
        profileResult = await _profileService.patchUserProfile(
          bio: _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          birthDate: _selectedBirthDate,
        );
      }

      setState(() {
        _isSaving = false;
      });

      if (profileResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: textGreen,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = profileResult.error ?? 'Failed to update profile';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An unexpected error occurred';
        _isSaving = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Date Picker
  // ══════════════════════════════════════════════════════════════
  Future<void> _selectBirthDate() async {
    if (_isLoading) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: textPink,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Shimmer Widgets
  // ══════════════════════════════════════════════════════════════
  Widget _buildShimmerBox({double? height, double? width}) {
    return Container(
      height: height ?? 20,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // UI Components
  // ══════════════════════════════════════════════════════════════
  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 12,
        right: 12,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: textPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            "Edit Profile",
            style: TextStyle(
              fontFamily: "Rubik",
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_isLoading) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.3),
            highlightColor: Colors.white.withOpacity(0.6),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white.withOpacity(0.3),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: textPink.withOpacity(0.5),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
        ],
      );
    }

    ImageProvider? imageProvider;

    if (_selectedAvatarFile != null) {
      imageProvider = FileImage(_selectedAvatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      String fullAvatarUrl = _avatarUrl!.startsWith('http')
          ? _avatarUrl!
          : 'https://nonabstemiously-stocky-cynthia.ngrok-free.dev$_avatarUrl';
      imageProvider = NetworkImage(fullAvatarUrl);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(
            Icons.person,
            color: Colors.grey,
            size: 48,
          )
              : null,
        ),
        Positioned(
          right: -4,
          top: -4,
          child: InkWell(
            onTap: _pickAvatar,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: textPink,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Digitalt',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentPurple.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: accentPurple.withOpacity(0.7), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: _isLoading
                    ? Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: _buildShimmerBox(
                    height: maxLines > 1 ? 60.0 : 20.0,
                  ),
                )
                    : TextFormField(
                  controller: controller,
                  readOnly: readOnly,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontFamily: "Rubik",
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateStr = _selectedBirthDate != null
        ? DateFormat('MMM dd, yyyy').format(_selectedBirthDate!)
        : 'Select birth date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'BIRTH DATE',
            style: TextStyle(
              fontFamily: 'Digitalt',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        InkWell(
          onTap: _selectBirthDate,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentPurple.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, color: accentPurple.withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLoading
                      ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: _buildShimmerBox(height: 20, width: 150),
                  )
                      : Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: "Rubik",
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _selectedBirthDate != null
                          ? Colors.black87
                          : Colors.black45,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, color: accentPurple.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (_isSaving || _isLoading) ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: textGreen,
            disabledBackgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text(
            "Save Changes",
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Build Method
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC0CB),
              Color(0xFFADD8E6),
              Color(0xFFE6E6FA),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: _error != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: textPink,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: textPink,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: textPink.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 24),

                          _buildTextField(
                            label: 'First Name',
                            icon: Icons.person_outline,
                            controller: _firstNameController,
                            keyboardType: TextInputType.name,
                          ),
                          _buildTextField(
                            label: 'Last Name',
                            icon: Icons.person_outline,
                            controller: _lastNameController,
                            keyboardType: TextInputType.name,
                          ),
                          _buildTextField(
                            label: 'Username',
                            icon: Icons.alternate_email,
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username is required';
                              }
                              if (value.trim().length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            label: 'Email (Read Only)',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            label: 'Bio',
                            icon: Icons.description_outlined,
                            controller: _bioController,
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                          ),
                          _buildTextField(
                            label: 'Location',
                            icon: Icons.location_on_outlined,
                            controller: _locationController,
                            keyboardType: TextInputType.text,
                          ),
                          _buildDateField(),

                          const SizedBox(height: 8),
                          _buildUpdateButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}