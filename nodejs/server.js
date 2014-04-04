/*************************************
//
// rfid-socketio app
//
**************************************/

// express magic
var express = require('express');
var app = express();
var server = require('http').createServer(app)
var io = require('socket.io').listen(server);

var serialPort = require("serialport");
var SerialPort = serialPort.SerialPort;
var sp;

var device  = require('express-device');

var runningPortNumber = 1337;


app.configure(function(){
	// I need to access everything in '/public' directly
	app.use(express.static(__dirname + '/public'));

	//set the view engine
	app.set('view engine', 'ejs');
	app.set('views', __dirname +'/views');

	app.use(device.capture());
});


// logs every request
app.use(function(req, res, next){
	// output every request in the array
	console.log({method:req.method, url: req.url, device: req.device});

	// goes onto the next function in line
	next();
});

app.get("/", function(req, res){
	res.render('index', {});
});

io.sockets.on('connection', function (socket) {

	socket.on('port:list', function(data, fn) {
		// reload the serial port
		serialPort.list(function(err, ports) {
			var names = [];
			ports.forEach(function(item) {
				names.push(item.comName);
			})
			fn({ports: names});
		});
	});

	socket.on('port:connect', function(data, fn) {
console.log(data)
		// add parser
		data.options.parser = serialPort.parsers.readline("\r\n");

		if (sp) {
			fn('A serial port has already connected, reconnecting...');
			sp.close(function(err) {});
			sp = new SerialPort(data.portName, data.options, true);
		} else {
            if (!data.portName) {
                socket.emit('port:connect:error', {msg: 'Please specify port name!'});
                return;
            } else {
                sp = new SerialPort(data.portName, data.options, true);
            }

		}

		sp.on('error', function(error) {
			socket.emit('port:connect:error', { msg: 'Connection error !' })
		});

		sp.on("open", function () {
			console.log('open');
			sp.on('data', function(data) {
				var decArr = data.replace('SERIAL:', '').split(',');
				var hexString = '';
				var decToHex = function(dec) { 
					var theInt = parseInt(dec);
					if (theInt < 17) {
						return '0' + theInt.toString(16);
					} else {
						return theInt.toString(16);
					}
				}
				decArr.forEach(function(dec) {
					hexString += decToHex(dec);
				});

				var result = hexString.toUpperCase();
				if (result.length == 10) {
					socket.emit('port:data', hexString.toUpperCase());
				}
			});
			fn(true);
		});
	});

	socket.on('port:close', function(data, fn){
		sp.close(function(err) { 
			if (err) {
				fn(false);
			} else {
				fn(true);
			}
		});
	});

	
	// io.sockets.emit('blast', {msg:"<span style=\"color:red !important\">someone connected</span>"});

	// socket.on('blast', function(data, fn){
	// 	console.log(data);
	// 	io.sockets.emit('blast', {msg:data.msg});

	// 	fn();//call the client back to clear out the field
	// });
	

});


server.listen(runningPortNumber);

