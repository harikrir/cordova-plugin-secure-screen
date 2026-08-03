var exec = require('cordova/exec');

var SecureScreen = {

    enableScreenshotProtection: function (success, error) {
        exec(
            success,
            error,
            'SecureScreen',
            'enableScreenshotProtection',
            []
        );
    },

    disableScreenshotProtection: function (success, error) {
        exec(
            success,
            error,
            'SecureScreen',
            'disableScreenshotProtection',
            []
        );
    },

    enableAppSwitcherBlur: function (success, error) {
        exec(
            success,
            error,
            'SecureScreen',
            'enableAppSwitcherBlur',
            []
        );
    },

    disableAppSwitcherBlur: function (success, error) {
        exec(
            success,
            error,
            'SecureScreen',
            'disableAppSwitcherBlur',
            []
        );
    }
};

module.exports = SecureScreen;
