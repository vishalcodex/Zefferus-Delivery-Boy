import 'dart:async';
import 'dart:convert';

import 'package:efood_multivendor_driver/data/api/api_checker.dart';
import 'package:efood_multivendor_driver/data/model/body/record_location_body.dart';
import 'package:efood_multivendor_driver/data/model/response/profile_model.dart';
import 'package:efood_multivendor_driver/data/model/response/response_model.dart';
import 'package:efood_multivendor_driver/data/repository/auth_repo.dart';
import 'package:efood_multivendor_driver/helper/route_helper.dart';
import 'package:efood_multivendor_driver/util/images.dart';
import 'package:efood_multivendor_driver/view/base/confirmation_dialog.dart';
import 'package:efood_multivendor_driver/view/base/custom_alert_dialog.dart';
import 'package:efood_multivendor_driver/view/base/custom_snackbar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as GeoCoding;
import 'package:location/location.dart';

class AuthController extends GetxController implements GetxService {
  final AuthRepo authRepo;
  AuthController({required this.authRepo}) {
    _notification = authRepo.isNotificationActive();
  }

  bool _isLoading = false;
  bool _notification = true;
  late ProfileModel _profileModel;
  late XFile? _pickedFile;
  late Timer _timer;
  Location _location = Location();

  bool get isLoading => _isLoading;
  bool get notification => _notification;
  ProfileModel get profileModel => _profileModel;
  XFile get pickedFile => _pickedFile!;

  Future<ResponseModel> login(String phone, String password) async {
    _isLoading = true;
    update();
    Response response = await authRepo.login(phone, password);
    ResponseModel responseModel;
    if (response.statusCode == 200) {
      authRepo.saveUserToken(
          response.body['token'], response.body['zone_wise_topic']);
      await authRepo.updateToken();
      responseModel = ResponseModel(true, 'successful');
    } else {
      responseModel = ResponseModel(false, response.statusText!);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<void> getProfile({bool? fromSignIn}) async {
    Response response = await authRepo.getProfileInfo();
    if (response.statusCode == 200) {
      _profileModel = ProfileModel.fromJson(response.body);
      if (_profileModel.active == 1 || (fromSignIn ?? false)) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever ||
            (GetPlatform.isIOS
                ? false
                : permission == LocationPermission.whileInUse)) {
          Get.dialog(
              ConfirmationDialog(
                icon: Images.location_permission,
                iconSize: 200,
                hasCancel: false,
                description: 'this_app_collects_location_data'.tr,
                onYesPressed: () {
                  Get.back();
                  _checkPermission(() => startLocationRecord());
                },
              ),
              barrierDismissible: false);
        } else {
          startLocationRecord();
        }
      } else {
        stopLocationRecord();
      }
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<bool> updateUserInfo(
      ProfileModel updateUserModel, String token) async {
    _isLoading = true;
    update();
    http.StreamedResponse response =
        await authRepo.updateProfile(updateUserModel, _pickedFile!, token);
    _isLoading = false;
    bool _isSuccess;
    if (response.statusCode == 200) {
      Map map = jsonDecode(await response.stream.bytesToString());
      String message = map["message"];
      _profileModel = updateUserModel;
      showCustomSnackBar(message, isError: false);
      _isSuccess = true;
    } else {
      ApiChecker.checkApi(Response(
          statusCode: response.statusCode,
          statusText: '${response.statusCode} ${response.reasonPhrase}'));
      _isSuccess = false;
    }
    update();
    return _isSuccess;
  }

  void pickImage() async {
    _pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    update();
  }

  Future<bool> changePassword(
      ProfileModel updatedUserModel, String password) async {
    _isLoading = true;
    update();
    bool _isSuccess;
    Response response =
        await authRepo.changePassword(updatedUserModel, password);
    _isLoading = false;
    if (response.statusCode == 200) {
      String message = response.body["message"];
      showCustomSnackBar(message, isError: false);
      _isSuccess = true;
    } else {
      ApiChecker.checkApi(response);
      _isSuccess = false;
    }
    update();
    return _isSuccess;
  }

  Future<bool> updateActiveStatus() async {
    Response response = await authRepo.updateActiveStatus();
    bool _isSuccess;
    if (response.statusCode == 200) {
      _profileModel.active = _profileModel.active == 0 ? 1 : 0;
      showCustomSnackBar(response.body['message'], isError: false);
      _isSuccess = true;
      if (_profileModel.active == 1) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever ||
            (GetPlatform.isIOS
                ? false
                : permission == LocationPermission.whileInUse)) {
          Get.dialog(
              ConfirmationDialog(
                icon: Images.location_permission,
                iconSize: 200,
                hasCancel: false,
                description: 'this_app_collects_location_data'.tr,
                onYesPressed: () {
                  Get.back();
                  _checkPermission(() => startLocationRecord());
                },
              ),
              barrierDismissible: false);
        } else {
          startLocationRecord();
        }
      } else {
        stopLocationRecord();
      }
    } else {
      ApiChecker.checkApi(response);
      _isSuccess = false;
    }
    update();
    return _isSuccess;
  }

  void startLocationRecord() {
    _location.enableBackgroundMode(enable: true);
    // _timer.cancel();
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      recordLocation();
    });
  }

  void stopLocationRecord() {
    _location.enableBackgroundMode(enable: false);
    _timer.cancel();
  }

  Future<void> recordLocation() async {
    print('--------------Adding location');
    final LocationData _locationResult = await _location.getLocation();
    print(
        'This is current Location: Latitude: ${_locationResult.latitude} Longitude: ${_locationResult.longitude}');
    String _address;
    try {
      List<GeoCoding.Placemark> _addresses =
          await GeoCoding.placemarkFromCoordinates(
              _locationResult.latitude!, _locationResult.longitude!);
      GeoCoding.Placemark _placeMark = _addresses.first;
      _address =
          '${_placeMark.name}, ${_placeMark.subAdministrativeArea}, ${_placeMark.isoCountryCode}';
    } catch (e) {
      _address = 'Unknown Location Found';
    }
    RecordLocationBody _recordLocation = RecordLocationBody(
      location: _address,
      latitude: _locationResult.latitude,
      longitude: _locationResult.longitude,
    );

    Response _response = await authRepo.recordLocation(_recordLocation);
    if (_response.statusCode == 200) {
      print(
          '--------------Added record Lat: ${_recordLocation.latitude} Lng: ${_recordLocation.longitude} Loc: ${_recordLocation.location}');
    } else {
      print('--------------Failed record');
    }
  }

  Future<ResponseModel> forgetPassword(String email) async {
    _isLoading = true;
    update();
    Response response = await authRepo.forgetPassword(email);

    ResponseModel responseModel;
    if (response.statusCode == 200) {
      responseModel = ResponseModel(true, response.body["message"]);
    } else {
      responseModel = ResponseModel(false, response.statusText!);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<void> updateToken() async {
    await authRepo.updateToken();
  }

  Future<ResponseModel> verifyToken(String number) async {
    _isLoading = true;
    update();
    Response response = await authRepo.verifyToken(number, _verificationCode);
    ResponseModel responseModel;
    if (response.statusCode == 200) {
      responseModel = ResponseModel(true, response.body["message"]);
    } else {
      responseModel = ResponseModel(false, response.statusText!);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<ResponseModel> resetPassword(String resetToken, String phone,
      String password, String confirmPassword) async {
    _isLoading = true;
    update();
    Response response = await authRepo.resetPassword(
        resetToken, phone, password, confirmPassword);
    ResponseModel responseModel;
    if (response.statusCode == 200) {
      responseModel = ResponseModel(true, response.body["message"]);
    } else {
      responseModel = ResponseModel(false, response.statusText!);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  String _verificationCode = '';

  String get verificationCode => _verificationCode;

  void updateVerificationCode(String query) {
    _verificationCode = query;
    update();
  }

  bool _isActiveRememberMe = false;

  bool get isActiveRememberMe => _isActiveRememberMe;

  void toggleRememberMe() {
    _isActiveRememberMe = !_isActiveRememberMe;
    update();
  }

  bool isLoggedIn() {
    return authRepo.isLoggedIn();
  }

  Future<bool> clearSharedData() async {
    return await authRepo.clearSharedData();
  }

  void saveUserNumberAndPassword(
      String number, String password, String countryCode) {
    authRepo.saveUserNumberAndPassword(number, password, countryCode);
  }

  String getUserNumber() {
    return authRepo.getUserNumber();
  }

  String getUserCountryCode() {
    return authRepo.getUserCountryCode();
  }

  String getUserPassword() {
    return authRepo.getUserPassword();
  }

  Future<bool> clearUserNumberAndPassword() async {
    return authRepo.clearUserNumberAndPassword();
  }

  String getUserToken() {
    return authRepo.getUserToken();
  }

  bool setNotificationActive(bool isActive) {
    _notification = isActive;
    authRepo.setNotificationActive(isActive);
    update();
    return _notification;
  }

  void initData() {
    _pickedFile = null;
  }

  void _checkPermission(Function callback) async {
    LocationPermission permission = await Geolocator.requestPermission();
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        (GetPlatform.isIOS
            ? false
            : permission == LocationPermission.whileInUse)) {
      Get.dialog(
          CustomAlertDialog(
              description: 'you_denied'.tr,
              onOkPressed: () async {
                Get.back();
                await Geolocator.requestPermission();
                _checkPermission(callback);
              }),
          barrierDismissible: false);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(
          CustomAlertDialog(
              description: 'you_denied_forever'.tr,
              onOkPressed: () async {
                Get.back();
                await Geolocator.openAppSettings();
                _checkPermission(callback);
              }),
          barrierDismissible: false);
    } else {
      callback();
    }
  }

  Future removeDriver() async {
    _isLoading = true;
    update();
    Response response = await authRepo.deleteDriver();
    _isLoading = false;
    if (response.statusCode == 200) {
      showCustomSnackBar('your_account_remove_successfully'.tr, isError: false);
      Get.find<AuthController>().clearSharedData();
      Get.find<AuthController>().stopLocationRecord();
      Get.offAllNamed(RouteHelper.getSignInRoute());
    } else {
      Get.back();
      ApiChecker.checkApi(response);
    }
  }
}
