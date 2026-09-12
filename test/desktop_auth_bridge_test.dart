import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/auth/repositories/desktop_auth_bridge.dart';

void main() {
  group('DesktopAuthBridge Unit Tests', () {
    late DesktopAuthBridge bridge;

    setUp(() {
      bridge = DesktopAuthBridge(
        apiKey: 'test-api-key',
        projectId: 'relay-86c7b',
      );
    });

    test('mintCustomToken produces RFC 7519 compliant RS256 JWT', () {
      const testUid = 'test_user_uid_12345';
      const testPhone = '+8801712345678';

      final token = bridge.mintCustomToken(
        uid: testUid,
        phoneNumber: testPhone,
      );

      expect(token, isNotEmpty);
      final parts = token.split('.');
      expect(parts.length, 3, reason: 'JWT must have header, payload, and signature');

      // 1. Verify Header
      final headerJson = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      ) as Map<String, dynamic>;
      expect(headerJson['alg'], 'RS256');
      expect(headerJson['typ'], 'JWT');

      // 2. Verify Payload Claims
      final payloadJson = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      expect(
        payloadJson['iss'],
        'firebase-adminsdk-fbsvc@relay-86c7b.iam.gserviceaccount.com',
      );
      expect(
        payloadJson['sub'],
        'firebase-adminsdk-fbsvc@relay-86c7b.iam.gserviceaccount.com',
      );
      expect(
        payloadJson['aud'],
        'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
      );
      expect(payloadJson['uid'], testUid);
      expect(payloadJson['claims']?['phoneNumber'], testPhone);

      final iat = payloadJson['iat'] as int;
      final exp = payloadJson['exp'] as int;
      expect(exp - iat, 3600, reason: 'Token expiry must be exactly 1 hour');

      // 3. Cryptographic Signature Verification via RSA Public Key (e, n)
      // s^e mod n == EM
      final nBytes = _b64UrlDecode(
        'zMXKbM56KvWR8Y41Bb_fxkOoCYpuK_j3pnq_1uXXdYI09UzTY2P8PCO4vVp9Ca6iRkulfl87dxakW2Zju1mccROy_l5CJfKMb2GQsYz21dAcP0t2iZ9uan6XPdwQ8eeux_GPUxV3WE5S6lriWbwt2I0ob4V0IEmZUsxbEK1JDTvLu_xFymhNvxjs4NjCzJx6sTJ_YT-a29nAWo_qDVAIzEM4-45-aEsKo-pkeTY8HMDijR-ldQrlxdj3Ntixig1ca5sOSrc84OKYgRWAiMxAntHnc0RZFIvTgb-N659i9JRbC0KVBNCUEIJuHtgyAmo4yLFYLdVRebs9jPqpmcxq1w',
      );
      final eBytes = _b64UrlDecode('AQAB');
      final n = _bytesToBigInt(nBytes);
      final e = _bytesToBigInt(eBytes);

      final sigBytes = _b64UrlDecode(parts[2]);
      final sigInt = _bytesToBigInt(sigBytes);

      final recoveredEmInt = sigInt.modPow(e, n);
      final recoveredEm = _bigIntToBytes(recoveredEmInt, 256);

      // Verify PKCS#1 v1.5 padding and SHA-256 hash match
      final signingInput = '${parts[0]}.${parts[1]}';
      final expectedHash = Uint8List.fromList(
        crypto.sha256.convert(utf8.encode(signingInput)).bytes,
      );

      expect(recoveredEm[0], 0x00);
      expect(recoveredEm[1], 0x01);
      expect(recoveredEm[recoveredEm.length - 52], 0x00);

      final recoveredHash = recoveredEm.sublist(recoveredEm.length - 32);
      expect(recoveredHash, equals(expectedHash));
    });

    test('sendVerificationCode maps network and quota errors correctly', () async {
      final mockClient = _MockHttpClient(
        statusCode: 400,
        responseBody: jsonEncode({
          'error': {
            'message': 'TOO_MANY_ATTEMPTS_TRY_LATER : Quota exceeded',
          },
        }),
      );

      final bridgeWithMock = DesktopAuthBridge(
        apiKey: 'test-api-key',
        projectId: 'relay-86c7b',
        httpClient: mockClient,
      );

      expect(
        () => bridgeWithMock.sendVerificationCode('+8801712345678'),
        throwsA(
          isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'quota-exceeded'),
        ),
      );
    });

    test('verifySmsCode maps invalid code error correctly', () async {
      final mockClient = _MockHttpClient(
        statusCode: 400,
        responseBody: jsonEncode({
          'error': {
            'message': 'INVALID_CODE : Invalid verification code',
          },
        }),
      );

      final bridgeWithMock = DesktopAuthBridge(
        apiKey: 'test-api-key',
        projectId: 'relay-86c7b',
        httpClient: mockClient,
      );

      expect(
        () => bridgeWithMock.verifySmsCode(
          sessionInfo: 'test_session',
          smsCode: '000000',
        ),
        throwsA(
          isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'invalid-verification-code'),
        ),
      );
    });

    test('verifySmsCode returns uid and phoneNumber on 200 OK', () async {
      final mockClient = _MockHttpClient(
        statusCode: 200,
        responseBody: jsonEncode({
          'localId': 'NJ3yVqIobgcgYbo2LgfSFn3kV1G3',
          'phoneNumber': '+8801712345678',
        }),
      );

      final bridgeWithMock = DesktopAuthBridge(
        apiKey: 'test-api-key',
        projectId: 'relay-86c7b',
        httpClient: mockClient,
      );

      final result = await bridgeWithMock.verifySmsCode(
        sessionInfo: 'valid_session',
        smsCode: '123456',
      );

      expect(result.uid, 'NJ3yVqIobgcgYbo2LgfSFn3kV1G3');
      expect(result.phoneNumber, '+8801712345678');
    });
  });
}

// Helpers for test verification
BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt number, int length) {
  final bytes = Uint8List(length);
  var temp = number;
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (temp & BigInt.from(0xff)).toInt();
    temp = temp >> 8;
  }
  return bytes;
}

Uint8List _b64UrlDecode(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return base64.decode(normalized);
}

// Lightweight mock HTTP infrastructure for headless tests
class _MockHttpClient implements HttpClient {
  _MockHttpClient({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _MockHttpClientRequest(
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  _MockHttpClientRequest({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  ContentType? contentType;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _MockHttpClientResponse({
    required this.statusCode,
    required this.responseBody,
  });

  @override
  final int statusCode;
  final String responseBody;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
