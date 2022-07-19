import 'dart:convert' show jsonDecode;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/type.dart';

const USER_INFO = """
{
  "sub": "sub",
  "https://authgear.com/claims/user/is_verified": true,
  "https://authgear.com/claims/user/is_anonymous": false,
  "https://authgear.com/claims/user/can_reauthenticate": true,

  "email": "user@example.com",
  "email_verified": true,
  "phone_number": "+85298765432",
  "phone_number_verified": true,
  "preferred_username": "user",
  "family_name": "Doe",
  "given_name": "John",
  "middle_name": "Middle",
  "name": "John Doe",
  "nickname": "John",
  "picture": "picture",
  "profile": "profile",
  "website": "website",
  "gender": "gender",
  "birthdate": "1970-01-01",
  "zoneinfo": "Etc/UTC",
  "locale": "zh-HK",
  "address": {
    "formatted": "10 Somewhere Street, Mong Kok, Kowloon, HK",
    "street_address": "10 Somewhere Street",
    "locality": "Mong Kok",
    "region": "Kowloon",
    "postal_code": "N/A",
    "country": "HK"
  },

  "custom_attributes": {
    "foobar": 42
  }
}
""";

void main() {
  test("UserInfo full", () {
    final raw = jsonDecode(USER_INFO);
    final actual = UserInfo.fromJSON(raw);
    expect(actual.sub, "sub");
    expect(actual.isAnonymous, false);
    expect(actual.isVerified, true);
    expect(actual.canReauthenticate, true);
    expect(actual.email, "user@example.com");
    expect(actual.emailVerified, true);
    expect(actual.phoneNumber, "+85298765432");
    expect(actual.phoneNumberVerified, true);
    expect(actual.preferredUsername, "user");
    expect(actual.familyName, "Doe");
    expect(actual.givenName, "John");
    expect(actual.middleName, "Middle");
    expect(actual.name, "John Doe");
    expect(actual.nickname, "John");
    expect(actual.picture, "picture");
    expect(actual.profile, "profile");
    expect(actual.website, "website");
    expect(actual.gender, "gender");
    expect(actual.birthdate, "1970-01-01");
    expect(actual.zoneinfo, "Etc/UTC");
    expect(actual.locale, "zh-HK");
    expect(actual.address?.formatted,
        "10 Somewhere Street, Mong Kok, Kowloon, HK");
    expect(actual.address?.streetAddress, "10 Somewhere Street");
    expect(actual.address?.locality, "Mong Kok");
    expect(actual.address?.region, "Kowloon");
    expect(actual.address?.postalCode, "N/A");
    expect(actual.address?.country, "HK");
    expect(actual.customAttributes["foobar"], 42);
    expect(actual.raw, raw);
  });

  test("UserInfo minimal", () {
    final raw = jsonDecode("""
    {
      "sub": "sub",
      "https://authgear.com/claims/user/is_verified": true,
      "https://authgear.com/claims/user/is_anonymous": false,
      "https://authgear.com/claims/user/can_reauthenticate": true
    }
    """);
    final actual = UserInfo.fromJSON(raw);
    expect(actual.sub, "sub");
    expect(actual.isAnonymous, false);
    expect(actual.isVerified, true);
    expect(actual.canReauthenticate, true);

    expect(actual.email, null);
    expect(actual.emailVerified, null);
    expect(actual.phoneNumber, null);
    expect(actual.phoneNumberVerified, null);
    expect(actual.preferredUsername, null);
    expect(actual.familyName, null);
    expect(actual.givenName, null);
    expect(actual.middleName, null);
    expect(actual.name, null);
    expect(actual.nickname, null);
    expect(actual.picture, null);
    expect(actual.profile, null);
    expect(actual.website, null);
    expect(actual.gender, null);
    expect(actual.birthdate, null);
    expect(actual.zoneinfo, null);
    expect(actual.locale, null);
    expect(actual.address, null);
    expect(actual.customAttributes, {});
    expect(actual.raw, raw);
  });
}
