import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

final _log = Logger('WindowsEncryption');

DynamicLibrary _crypt32 = DynamicLibrary.open('crypt32.dll');
DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final _cryptProtectData = _crypt32.lookupFunction<
    Int32 Function(Pointer<DATA_BLOB>, Pointer<Utf16>, Pointer<DATA_BLOB>,
        Pointer<Void>, Pointer<Void>, Uint32, Pointer<DATA_BLOB>),
    int Function(Pointer<DATA_BLOB>, Pointer<Utf16>, Pointer<DATA_BLOB>,
        Pointer<Void>, Pointer<Void>, int, Pointer<DATA_BLOB>)>('CryptProtectData');

final _cryptUnprotectData = _crypt32.lookupFunction<
    Int32 Function(Pointer<DATA_BLOB>, Pointer<Pointer<Utf16>>,
        Pointer<DATA_BLOB>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<DATA_BLOB>),
    int Function(Pointer<DATA_BLOB>, Pointer<Pointer<Utf16>>,
        Pointer<DATA_BLOB>, Pointer<Void>, Pointer<Void>, int, Pointer<DATA_BLOB>)>('CryptUnprotectData');

final _localFree = _kernel32.lookupFunction<
    Pointer<Void> Function(Pointer<Void>),
    Pointer<Void> Function(Pointer<Void>)>('LocalFree');

final class DATA_BLOB extends Struct {
  @Int32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

Pointer<DATA_BLOB> _allocBlob(Uint8List data) {
  final blob = calloc<DATA_BLOB>();
  blob.ref.cbData = data.length;
  blob.ref.pbData = calloc<Uint8>(data.length);
  for (var i = 0; i < data.length; i++) {
    blob.ref.pbData[i] = data[i];
  }
  return blob;
}

Uint8List? _readBlob(Pointer<DATA_BLOB> blob) {
  if (blob.ref.cbData == 0 || blob.ref.pbData == nullptr) return null;
  final result = Uint8List(blob.ref.cbData);
  for (var i = 0; i < blob.ref.cbData; i++) {
    result[i] = blob.ref.pbData[i];
  }
  return result;
}

void _freeBlob(Pointer<DATA_BLOB> blob) {
  if (blob.ref.pbData != nullptr) {
    _localFree(blob.ref.pbData.cast<Void>());
  }
  calloc.free(blob);
}

const int CRYPTPROTECT_UI_FORBIDDEN = 0x00000001;

/// Encrypt plaintext using Windows DPAPI (CryptProtectData).
/// Returns base64-encoded ciphertext suitable for string storage.
String? encrypt(String plaintext) {
  try {
    final data = Uint8List.fromList(plaintext.codeUnits);
    final inBlob = _allocBlob(data);
    final outBlob = calloc<DATA_BLOB>();

    final result = _cryptProtectData(
      inBlob,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      CRYPTPROTECT_UI_FORBIDDEN,
      outBlob,
    );

    _freeBlob(inBlob);

    if (result == 0) {
      calloc.free(outBlob);
      _log.warning('encrypt: CryptProtectData failed');
      return null;
    }

    final encrypted = _readBlob(outBlob);
    _freeBlob(outBlob);

    if (encrypted == null) return null;
    return base64Encode(encrypted);
  } catch (e) {
    _log.warning('encrypt failed: $e');
    return null;
  }
}

/// Decrypt base64-encoded ciphertext using Windows DPAPI (CryptUnprotectData).
String? decrypt(String ciphertext) {
  try {
    final data = base64Decode(ciphertext);
    final inBlob = _allocBlob(data);
    final outBlob = calloc<DATA_BLOB>();

    final result = _cryptUnprotectData(
      inBlob,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      CRYPTPROTECT_UI_FORBIDDEN,
      outBlob,
    );

    _freeBlob(inBlob);

    if (result == 0) {
      calloc.free(outBlob);
      _log.warning('decrypt: CryptUnprotectData failed');
      return null;
    }

    final decrypted = _readBlob(outBlob);
    _freeBlob(outBlob);

    if (decrypted == null) return null;
    return String.fromCharCodes(decrypted);
  } catch (e) {
    _log.warning('decrypt failed: $e');
    return null;
  }
}
