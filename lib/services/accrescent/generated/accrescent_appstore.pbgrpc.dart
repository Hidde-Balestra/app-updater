// This is a generated file - do not edit.
//
// Generated from accrescent_appstore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'accrescent_appstore.pb.dart' as $0;

export 'accrescent_appstore.pb.dart';

@$pb.GrpcServiceName('accrescent.appstore.v1.AppService')
class AppServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AppServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.GetAppPackageInfoResponse> getAppPackageInfo(
    $0.GetAppPackageInfoRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAppPackageInfo, request, options: options);
  }

  // method descriptors

  static final _$getAppPackageInfo = $grpc.ClientMethod<
          $0.GetAppPackageInfoRequest, $0.GetAppPackageInfoResponse>(
      '/accrescent.appstore.v1.AppService/GetAppPackageInfo',
      ($0.GetAppPackageInfoRequest value) => value.writeToBuffer(),
      $0.GetAppPackageInfoResponse.fromBuffer);
}

@$pb.GrpcServiceName('accrescent.appstore.v1.AppService')
abstract class AppServiceBase extends $grpc.Service {
  $core.String get $name => 'accrescent.appstore.v1.AppService';

  AppServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetAppPackageInfoRequest,
            $0.GetAppPackageInfoResponse>(
        'GetAppPackageInfo',
        getAppPackageInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetAppPackageInfoRequest.fromBuffer(value),
        ($0.GetAppPackageInfoResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetAppPackageInfoResponse> getAppPackageInfo_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetAppPackageInfoRequest> $request) async {
    return getAppPackageInfo($call, await $request);
  }

  $async.Future<$0.GetAppPackageInfoResponse> getAppPackageInfo(
      $grpc.ServiceCall call, $0.GetAppPackageInfoRequest request);
}
