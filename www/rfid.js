/*jshint camelcase: false */
'use strict';

angular.module('app.hw')

.factory('RFIDService', [
  'Restangular',
  '$q',
  '$socket',
  '$rootScope',
  '$notification',
  function(Restangular, $q, $socket, $rootScope, $notification) {
    var devices = null,
        selectedDevice = null;
    
    return {
      get: function(serial) {
        return Restangular.one('rfid',serial).get({ group: 'details' });
      },
      
      registerUserCard: function(serial) {
  //        POST /users/rfid serial=
        return Restangular.oneUrl('users').post('rfid',{serial: serial});
      },
            
      getConnection: function() {
        return $socket;
      },
      
      getDevices: function() {
        var d = $q.defer();
        $socket.emit('port:list',{}, function(result){
          devices = result.ports;
          d.resolve(devices);
        });
        return d.promise;
      },
      
      connect: function(device) {
        var d = $q.defer();
        selectedDevice = device;
        $socket.emit('port:connect', {portName: selectedDevice, options: { baudrate: 9600 }}, function(result) {
          d.resolve(result);
        });
        return d.promise;
      },
      
      disconnect: function() {
        $socket.disconnect();
        if (selectedDevice) { $notification.warning('RFID Reader disconnected'); }
        $rootScope.$broadcast('rfid.off');
        selectedDevice = null;
      },
      
      autoConnect: function() {
        var d = $q.defer();
        var self = this;
        this.getDevices().then(function(devices){
          var device = null;
          angular.forEach(devices,function(port){
            if (port.match(/A600853H$/) || port.match('/ttyUSB0$/')){
              device = port;
            }
          });
          if (!device) {
            d.reject('No standard device found');
          }
          self.connect(device).then(function(result){
            $rootScope.$broadcast('rfid.on');
            $notification.info('RFID Reader connected');
            d.resolve(result);
          });
        });
        return d.promise;
      },
      
      close: function(device) {
        $socket.emit('port:close', {portName: device, options: {baudrate: 9600}}, function(result){
          return result;
        });
      }
    };
  }
]);
