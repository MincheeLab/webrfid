var app = angular.module('app', ['app.services']);

app.controller('SerialPortCtrl', ['$scope', 'socket', function($scope, socket) {
	$scope.refreshPorts = function() {
		socket.emit('port:list', {}, function(result){
            $scope.availablePorts = result.ports;
        });
	};

    $scope.connectPort = function(portName) {
        socket.emit('port:connect', {portName: portName, options: { baudrate: 9600 }}, function(result) {
            console.log(result);
        });
    };

    socket.on('port:connect:error', function(data) {
        $scope.connectError = data.msg;
    });

    socket.on('port:data', function(data) {
        console.log(data);
    });

    // socket.on('port:list', function(data) {
    //     console.log(data);
    // });
}]);var app = angular.module('app.services', []);

app.factory('socket', function ($rootScope) {
  var socket = io.connect();
  return {
    on: function (eventName, callback) {
      socket.on(eventName, function () {  
        var args = arguments;
        $rootScope.$apply(function () {
          callback.apply(socket, args);
      });
    });
  },
  emit: function (eventName, data, callback) {
      socket.emit(eventName, data, function () {
        var args = arguments;
        $rootScope.$apply(function () {
          if (callback) {
            callback.apply(socket, args);
        }
    });
    })
  }
};
});