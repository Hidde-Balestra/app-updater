// This is a generated file - do not edit.
//
// Generated from accrescent_appstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class GetAppPackageInfoRequest extends $pb.GeneratedMessage {
  factory GetAppPackageInfoRequest({
    $core.String? appId,
  }) {
    final result = create();
    if (appId != null) result.appId = appId;
    return result;
  }

  GetAppPackageInfoRequest._();

  factory GetAppPackageInfoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAppPackageInfoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAppPackageInfoRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'accrescent.appstore.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'appId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAppPackageInfoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAppPackageInfoRequest copyWith(
          void Function(GetAppPackageInfoRequest) updates) =>
      super.copyWith((message) => updates(message as GetAppPackageInfoRequest))
          as GetAppPackageInfoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAppPackageInfoRequest create() => GetAppPackageInfoRequest._();
  @$core.override
  GetAppPackageInfoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAppPackageInfoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAppPackageInfoRequest>(create);
  static GetAppPackageInfoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get appId => $_getSZ(0);
  @$pb.TagNumber(1)
  set appId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppId() => $_clearField(1);
}

class PackageInfo extends $pb.GeneratedMessage {
  factory PackageInfo({
    $fixnum.Int64? versionCode,
    $core.String? versionName,
  }) {
    final result = create();
    if (versionCode != null) result.versionCode = versionCode;
    if (versionName != null) result.versionName = versionName;
    return result;
  }

  PackageInfo._();

  factory PackageInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PackageInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackageInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'accrescent.appstore.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'versionCode', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'versionName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackageInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackageInfo copyWith(void Function(PackageInfo) updates) =>
      super.copyWith((message) => updates(message as PackageInfo))
          as PackageInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PackageInfo create() => PackageInfo._();
  @$core.override
  PackageInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PackageInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackageInfo>(create);
  static PackageInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get versionCode => $_getI64(0);
  @$pb.TagNumber(1)
  set versionCode($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersionCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersionCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get versionName => $_getSZ(1);
  @$pb.TagNumber(2)
  set versionName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersionName() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersionName() => $_clearField(2);
}

class GetAppPackageInfoResponse extends $pb.GeneratedMessage {
  factory GetAppPackageInfoResponse({
    PackageInfo? packageInfo,
  }) {
    final result = create();
    if (packageInfo != null) result.packageInfo = packageInfo;
    return result;
  }

  GetAppPackageInfoResponse._();

  factory GetAppPackageInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAppPackageInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAppPackageInfoResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'accrescent.appstore.v1'),
      createEmptyInstance: create)
    ..aOM<PackageInfo>(1, _omitFieldNames ? '' : 'packageInfo',
        subBuilder: PackageInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAppPackageInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAppPackageInfoResponse copyWith(
          void Function(GetAppPackageInfoResponse) updates) =>
      super.copyWith((message) => updates(message as GetAppPackageInfoResponse))
          as GetAppPackageInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAppPackageInfoResponse create() => GetAppPackageInfoResponse._();
  @$core.override
  GetAppPackageInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAppPackageInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAppPackageInfoResponse>(create);
  static GetAppPackageInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PackageInfo get packageInfo => $_getN(0);
  @$pb.TagNumber(1)
  set packageInfo(PackageInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPackageInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackageInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  PackageInfo ensurePackageInfo() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
