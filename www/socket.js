/*global io */
'use strict';

angular.module('usj.services')

.factory('$socket', [
  '$rootScope',
  '$notification',
  function ($rootScope, $notification) {
    var socket,
        isActive = false;
    
    return {
      connect: function(url) {
        url = url || 'http://localhost:1337';
        socket = io.connect(url);
        
        socket.on('error', function(){
          $rootScope.$broadcast('socket.error');
          isActive = false;
        });

        socket.on('port:connect:error', function(data) {
          $rootScope.$broadcast('socket.error.connect',data.msg);
          isActive = false;
          $notification.error('RFID Reader disconnected','Reconnect by selecting the device.');
        });
      },
      
      on: function (eventName, callback) {
        if (angular.isUndefined(socket)) {
          this.connect();
        }
        socket.on(eventName, function () {
          var args = arguments;
          $rootScope.$apply(function () {
            callback.apply(socket, args);
          });
        });
      },
      
      emit: function (eventName, data, callback) {
        if (angular.isUndefined(socket)) {
          this.connect();
        }
        socket.emit(eventName, data, function () {
          var args = arguments;
          $rootScope.$apply(function () {
            if (callback) {
              callback.apply(socket, args);
            }
          });
        });
      },
      
      isActive: function() {
        return isActive;
      },
      
      disconnect: function() {
        if (socket) {
          socket.removeAllListeners('port:data');
        }
      }
    };
  }
]);