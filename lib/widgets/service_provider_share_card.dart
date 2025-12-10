import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ServiceProviderShareCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String? altPhone;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String arcId;
  final String providerType;
  final String? registrationNumber;
  final String? profileImageUrl;
  final String qrDataString;
  final double? maxWidth;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData providerIcon;

  const ServiceProviderShareCard({
    Key? key,
    required this.name,
    required this.email,
    required this.phone,
    this.altPhone,
    this.address,
    this.city,
    this.state,
    this.pincode,
    required this.arcId,
    required this.providerType,
    this.registrationNumber,
    this.profileImageUrl,
    required this.qrDataString,
    this.maxWidth,
    required this.primaryColor,
    required this.secondaryColor,
    required this.providerIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive size to avoid clipping on small screens
    final double targetWidth =
        (maxWidth != null && maxWidth! > 0) ? maxWidth! : 1080;
    final double width = targetWidth.clamp(600, 1080);
    final double height = width * 0.56; // aspect ratio ~ 1080x600
    final double leftPanelWidth = width * 0.16; // left panel for profile image
    final double qrBoxSize =
        width * 0.28; // bigger QR box for better visibility
    final double avatarRadius = width * 0.065; // avatar size
    final double nameFont = width * 0.042; // larger title font
    final double lineFont = width * 0.026; // slightly larger line font
    final double subtleLineFont =
        lineFont * 0.92; // smaller for long address/location

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.02),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(width * 0.025),
            child: Column(
              children: [
                // Top row: Profile image and name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image in top-left
                    Container(
                      width: leftPanelWidth,
                      height: leftPanelWidth,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: primaryColor,
                          backgroundImage: (profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty)
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          child: (profileImageUrl == null ||
                                  profileImageUrl!.isEmpty)
                              ? Icon(providerIcon,
                                  size: avatarRadius, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    // Name and basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: nameFont,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: width * 0.01),
                          Row(
                            children: [
                              Icon(Icons.badge,
                                  size: lineFont + 2,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'ARC ID: $arcId',
                                  style: TextStyle(
                                    fontSize: lineFont,
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: width * 0.02),
                // Middle row: Details and QR code
                Row(
                  children: [
                    // Left side: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(providerIcon,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'Type: $providerType',
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151),
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  phone,
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((altPhone ?? '').isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              children: [
                                Icon(Icons.phone_in_talk,
                                    size: lineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Flexible(
                                  child: Text(
                                    altPhone!,
                                    style: TextStyle(
                                        fontSize: lineFont,
                                        color: const Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.email,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if ((address ?? '').isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on,
                                    size: subtleLineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Expanded(
                                  child: Text(
                                    address!,
                                    style: TextStyle(
                                        fontSize: subtleLineFont,
                                        color: const Color(0xFF374151)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (((city ?? '').isNotEmpty) ||
                              ((state ?? '').isNotEmpty) ||
                              ((pincode ?? '').isNotEmpty)) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              children: [
                                Icon(Icons.map,
                                    size: subtleLineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Flexible(
                                  child: Text(
                                    [city, state, pincode]
                                        .where((e) => (e ?? '').isNotEmpty)
                                        .join(', '),
                                    style: TextStyle(
                                        fontSize: subtleLineFont,
                                        color: const Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.02),
                    // Right side: QR code
                    Container(
                      width: qrBoxSize,
                      height: qrBoxSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.1),
                            secondaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // QR Code
                            Container(
                              width: qrBoxSize - 24,
                              height: qrBoxSize - 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: QrImageView(
                                  data: qrDataString,
                                  version: QrVersions.auto,
                                  size: qrBoxSize - 32,
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
