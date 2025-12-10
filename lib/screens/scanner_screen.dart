import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
 
export 'scanner_mobile.dart' if (dart.library.html) 'scanner_web.dart'; 