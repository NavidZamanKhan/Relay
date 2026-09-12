import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:firebase_auth/firebase_auth.dart';

/// Desktop bridge providing Identity Toolkit REST fallback and
/// client-side Firebase custom token generation for platforms where
/// native phone verification is unsupported (macOS desktop).
class DesktopAuthBridge {
  DesktopAuthBridge({
    required String apiKey,
    required String projectId,
    HttpClient? httpClient,
  })  : _apiKey = apiKey,
        _projectId = projectId,
        _client = httpClient;

  final String _apiKey;
  final String _projectId;
  final HttpClient? _client;

  String get projectId => _projectId;

  String get _serviceAccountEmail =>
      'firebase-adminsdk-fbsvc@$_projectId.iam.gserviceaccount.com';

  // Base64URL encoded RSA 2048-bit key parameters for local token minting
  static const Map<String, String> _jwk = {
    'kty': 'RSA',
    'n':
        'zMXKbM56KvWR8Y41Bb_fxkOoCYpuK_j3pnq_1uXXdYI09UzTY2P8PCO4vVp9Ca6iRkulfl87dxakW2Zju1mccROy_l5CJfKMb2GQsYz21dAcP0t2iZ9uan6XPdwQ8eeux_GPUxV3WE5S6lriWbwt2I0ob4V0IEmZUsxbEK1JDTvLu_xFymhNvxjs4NjCzJx6sTJ_YT-a29nAWo_qDVAIzEM4-45-aEsKo-pkeTY8HMDijR-ldQrlxdj3Ntixig1ca5sOSrc84OKYgRWAiMxAntHnc0RZFIvTgb-N659i9JRbC0KVBNCUEIJuHtgyAmo4yLFYLdVRebs9jPqpmcxq1w',
    'e': 'AQAB',
    'd':
        'LfVygksxRjUJhXKKWfj_i2sh6spEAeCGDLpeFihN3FTV9_w_MX5-XS0TSIRnreWhDC_sO9m56feN-emYFrN9Fi_6q3aSWBwBAvqd1Au0Vra3sEkKmMbMrGAvJ7Ydo32BT-TaayZVO9-QYoL1bHh8va6o1abZMmnyXI_7HFoYHDzZfVwseJCoJIVph0oS8QRXjxuPkaNTP85bajCNESSZRyjifM78edKK71OHIykSfezzNgSCjMeh_p7Ud8ktHUlpjG96sI_77X3mOwfIFQ41JSPuxuiys6BCGYABqgb0kycxgmkihesfneTpXpBKt2-1Bj1O6_A0CcC1X5W-2zdImQ',
    'p':
        '80B3ueiHoRzZI94IiKiQlSbjZeGXef7T1cviYTb8yLbvNLLuIIPEaRz4RFnstb-aNqDyFmDlYIuknNwyP2ZzLpCsi3g-6bKjsFICoYSR19p_mhEf4ohDB-Ef02tW1TzMq7vYWJ3ClJ2vTMGZHuS8gnM1pYz7m4lVJ3Jey9hORgM',
    'q':
        '14ETWgp6y2s97A0SSjQSJvSK9WqDKeBjlRe4UhshWEeN3_Lm5sfps1WCbxdLg9cc3t2Uon8yggm4Gh8ZTHNf3DJjSrFJIiCESQ64CT4BY6TaZ8nYsQVVAChpF_G7OFkNaY-FcKY9DL7AIzxSxX9YHB2BUQm-eS5uoTGvVX-HKZ0',
    'dp':
        '4Q6ldyjvy52gPTIhnSawVn8bZ1i4SFP_9E_lzGIOsTmnyY8_CHBBWatG_B5jBqkWajKwqQnPT2sDy2ljSAtmyA9sxMFlG91-2xSVgJDiSt7KrmXnpTTDJ9gfFQG73iCZkM6EVUDpFY1q8k4weEfTLbKgUOJGrFn8ojmMAXfIu7c',
    'dq':
        'c6zbIFfDtfDomg4iJSZyH-rfs__qS84gZeUHkTry2Rn_c5hEjNf9_78EdnEAndIXsyEpKVgxWk-xPIQ45ip_6Ag799nVsbXWjAiUjJF12XChs1hLMin0iFMopiuhHQvgASuCqwbweijhpYg5vb0vJFhKE5-xWAauZ2PuA2yitpk',
    'qi':
        'fHrwSpRk-OqLSeUjMkvmP6PHEuTYBZ0GlfXWxrRIZ0gXvSky0juDZ-W7pf9B1gVSVJ1aqPkMuyVb6V3z-7ElbhHtt1PeUQjp8H31k5rvw-K9nRntS_Zzjsezz3exmkk0jFemGPs-J_ohJBWsWY77C_cds5QasAZADd6IMv3rDBU',
  };

  HttpClient _getHttpClient() => _client ?? HttpClient();

  /// Requests SMS verification code via Identity Toolkit REST API.
  Future<String> sendVerificationCode(String phoneNumber) async {
    final client = _getHttpClient();
    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=$_apiKey',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'phoneNumber': phoneNumber}));
      final response = await request.close();
      final bodyString = await response.transform(utf8.decoder).join();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final error = body['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? 'FAILED_TO_SEND_SMS';
        _mapAndThrowFirebaseError(message);
      }

      final sessionInfo = body['sessionInfo'] as String?;
      if (sessionInfo == null || sessionInfo.isEmpty) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'Unable to initialize verification session.',
        );
      }
      return sessionInfo;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Verifies 6-digit SMS code against active session via Identity Toolkit REST API.
  Future<({String uid, String phoneNumber})> verifySmsCode({
    required String sessionInfo,
    required String smsCode,
  }) async {
    final client = _getHttpClient();
    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=$_apiKey',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'sessionInfo': sessionInfo,
        'code': smsCode,
      }));
      final response = await request.close();
      final bodyString = await response.transform(utf8.decoder).join();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final error = body['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? 'INVALID_CODE';
        _mapAndThrowFirebaseError(message);
      }

      final localId = body['localId'] as String?;
      final phone = body['phoneNumber'] as String? ?? '';
      if (localId == null || localId.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Verification succeeded but user ID was missing.',
        );
      }
      return (uid: localId, phoneNumber: phone);
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Mints a signed Firebase Custom Token in pure Dart using RS256 with CRT optimization.
  String mintCustomToken({
    required String uid,
    required String phoneNumber,
  }) {
    final n = _bytesToBigInt(_b64UrlDecode(_jwk['n']!));
    final d = _bytesToBigInt(_b64UrlDecode(_jwk['d']!));
    final p = _bytesToBigInt(_b64UrlDecode(_jwk['p']!));
    final q = _bytesToBigInt(_b64UrlDecode(_jwk['q']!));
    final dp = _bytesToBigInt(_b64UrlDecode(_jwk['dp']!));
    final dq = _bytesToBigInt(_b64UrlDecode(_jwk['dq']!));
    final qi = _bytesToBigInt(_b64UrlDecode(_jwk['qi']!));

    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})))
        .replaceAll('=', '');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payloadJson = {
      'iss': _serviceAccountEmail,
      'sub': _serviceAccountEmail,
      'aud':
          'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
      'iat': now,
      'exp': now + 3600,
      'uid': uid,
      'claims': {
        if (phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      },
    };

    final payload = base64Url
        .encode(utf8.encode(jsonEncode(payloadJson)))
        .replaceAll('=', '');
    final signingInput = '$header.$payload';

    final sigBytes = _rsaSignSha256(
      message: Uint8List.fromList(utf8.encode(signingInput)),
      n: n,
      d: d,
      p: p,
      q: q,
      dp: dp,
      dq: dq,
      qi: qi,
    );

    final sigB64 = base64Url.encode(sigBytes).replaceAll('=', '');
    return '$signingInput.$sigB64';
  }

  static Never _mapAndThrowFirebaseError(String message) {
    if (message.contains('INVALID_CODE') || message.contains('INVALID_VERIFICATION_CODE')) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code is invalid. Please try again.',
      );
    }
    if (message.contains('SESSION_EXPIRED')) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'The verification session has expired. Please request a new code.',
      );
    }
    if (message.contains('TOO_MANY_ATTEMPTS_TRY_LATER') || message.contains('QUOTA_EXCEEDED')) {
      throw FirebaseAuthException(
        code: 'quota-exceeded',
        message: 'Too many requests. Please try again later.',
      );
    }
    if (message.contains('INVALID_PHONE_NUMBER')) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'The phone number is formatted incorrectly.',
      );
    }
    throw FirebaseAuthException(
      code: 'network-request-failed',
      message: message,
    );
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = Uint8List(length);
    var temp = number;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }

  static Uint8List _b64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64.decode(normalized);
  }

  static Uint8List _pkcs1PadSha256(Uint8List hash, int keyByteLen) {
    const digestInfoPrefix = [
      0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03,
      0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
    ];
    final prefix = Uint8List.fromList(digestInfoPrefix);
    final tLen = prefix.length + hash.length;
    final psLen = keyByteLen - tLen - 3;

    final em = Uint8List(keyByteLen);
    em[0] = 0x00;
    em[1] = 0x01;
    for (var i = 2; i < 2 + psLen; i++) {
      em[i] = 0xff;
    }
    em[2 + psLen] = 0x00;
    em.setRange(3 + psLen, 3 + psLen + prefix.length, prefix);
    em.setRange(3 + psLen + prefix.length, keyByteLen, hash);
    return em;
  }

  static Uint8List _rsaSignSha256({
    required Uint8List message,
    required BigInt n,
    required BigInt d,
    required BigInt p,
    required BigInt q,
    required BigInt dp,
    required BigInt dq,
    required BigInt qi,
  }) {
    final hash = Uint8List.fromList(crypto.sha256.convert(message).bytes);
    final em = _pkcs1PadSha256(hash, 256);
    final m = _bytesToBigInt(em);

    final m1 = m.modPow(dp, p);
    final m2 = m.modPow(dq, q);
    var diff = m1 - m2;
    while (diff < BigInt.zero) {
      diff += p;
    }
    final h = (diff * qi) % p;
    final s = m2 + h * q;

    return _bigIntToBytes(s, 256);
  }
}
