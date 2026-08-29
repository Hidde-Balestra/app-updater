// This is a generated file - do not edit.
//
// Generated from accrescent_appstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use getAppPackageInfoRequestDescriptor instead')
const GetAppPackageInfoRequest$json = {
  '1': 'GetAppPackageInfoRequest',
  '2': [
    {'1': 'app_id', '3': 1, '4': 1, '5': 9, '10': 'appId'},
  ],
};

/// Descriptor for `GetAppPackageInfoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAppPackageInfoRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRBcHBQYWNrYWdlSW5mb1JlcXVlc3QSFQoGYXBwX2lkGAEgASgJUgVhcHBJZA==');

@$core.Deprecated('Use packageInfoDescriptor instead')
const PackageInfo$json = {
  '1': 'PackageInfo',
  '2': [
    {'1': 'version_code', '3': 1, '4': 1, '5': 4, '10': 'versionCode'},
    {'1': 'version_name', '3': 2, '4': 1, '5': 9, '10': 'versionName'},
  ],
};

/// Descriptor for `PackageInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List packageInfoDescriptor = $convert.base64Decode(
    'CgtQYWNrYWdlSW5mbxIhCgx2ZXJzaW9uX2NvZGUYASABKARSC3ZlcnNpb25Db2RlEiEKDHZlcn'
    'Npb25fbmFtZRgCIAEoCVILdmVyc2lvbk5hbWU=');

@$core.Deprecated('Use getAppPackageInfoResponseDescriptor instead')
const GetAppPackageInfoResponse$json = {
  '1': 'GetAppPackageInfoResponse',
  '2': [
    {
      '1': 'package_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.accrescent.appstore.v1.PackageInfo',
      '10': 'packageInfo'
    },
  ],
};

/// Descriptor for `GetAppPackageInfoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAppPackageInfoResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRBcHBQYWNrYWdlSW5mb1Jlc3BvbnNlEkYKDHBhY2thZ2VfaW5mbxgBIAEoCzIjLmFjY3'
        'Jlc2NlbnQuYXBwc3RvcmUudjEuUGFja2FnZUluZm9SC3BhY2thZ2VJbmZv');
