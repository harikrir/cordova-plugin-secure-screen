var exec = require('cordova/exec');

var SecureScreen = {

    enableScreenshotProtection: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'enableScreenshotProtection', []);
    },

    disableScreenshotProtection: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'disableScreenshotProtection', []);
    },

    enableAppSwitcherBlur: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'enableAppSwitcherBlur', []);
    },

    disableAppSwitcherBlur: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'disableAppSwitcherBlur', []);
    },

    registerScreenshotListener: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'registerScreenshotListener', []);
    },

    enableScreenRecordingProtection: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'enableScreenRecordingProtection', []);
    },

    disableScreenRecordingProtection: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'SecureScreen', 'disableScreenRecordingProtection', []);
    }

};

module.exports = SecureScreen;
