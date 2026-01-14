import 'dart:typed_data';

class Attachment {
  final String name;
  final Uint8List? bytes;
  final String? mimeType;
  
  Attachment({
    required this.name, 
    this.bytes, 
    this.mimeType
  });
}
