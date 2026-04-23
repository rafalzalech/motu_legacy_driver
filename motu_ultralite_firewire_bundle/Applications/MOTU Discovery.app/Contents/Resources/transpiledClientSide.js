"use strict";

function _defaults(obj, defaults) { var keys = Object.getOwnPropertyNames(defaults); for (var i = 0; i < keys.length; i++) { var key = keys[i]; var value = Object.getOwnPropertyDescriptor(defaults, key); if (value && value.configurable && obj[key] === undefined) { Object.defineProperty(obj, key, value); } } return obj; }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : _defaults(subClass, superClass); }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function isMOTUUID(uid) {
	return uid.indexOf('0001f2fffe') == 0;
}

function clientID() {
	return 'xxxxxxxxxx'.replace(/[x]/g, function (c) {
		var r = Math.round(Math.random() * 10);
		return r.toString(10);
	});
}

function debounce(f, context, time) {
	var tid = null;
	function _throttled() {
		if (tid === null) {
			var len = arguments.length;
			var args = new Array(len);
			for (var i = 0; i < len; i++) {
				args[i] = arguments[i];
			}
			tid = setTimeout(function () {
				f.apply(context, args);
				tid = null;
			}, time);
		}
	}
	return _throttled;
}

function send(url) {
	return new Promise(function (resolve, reject) {
		var xhr = new XMLHttpRequest();

		function ensureReadiness() {
			if (xhr.readyState < 4) return;
			if (xhr.status !== 200 && xhr.status !== 304) reject();
			if (xhr.readyState === 4) resolve(xhr.response);
		}
		xhr.onreadystatechange = ensureReadiness;
		xhr.open('GET', url, true);
		xhr.timeout = 5000;
		// xhr.setRequestHeader('Access-Control-Allow-Origin', '*');
		xhr.send('');
	});
}

// Return 1 if a > b
// Return -1 if a < b
// Return 0 if a == b
function versionCompare(a, b) {
	var parseVersionString = function parseVersionString(str) {
		if (typeof str != 'string') {
			return false;
		}
		var x = /(\d+)\.(\d+)\.(\d+)\+?[^0-9.]*(\d*)/.exec(str);

		// parse from string or default to 0 if can't parse
		var major = parseInt(x[1], 10) || 0;
		var minor = parseInt(x[2], 10) || 0;
		var patch = parseInt(x[3], 10) || 0;
		var build = parseInt(x[4], 10) || 0;
		return {
			major: major,
			minor: minor,
			patch: patch,
			build: build
		};
	};
	var _a = parseVersionString(a);
	var _b = parseVersionString(b);
	if (_a.major > _b.major) return 1;else if (_a.major < _b.major) return -1;else if (_a.minor > _b.minor) return 1;else if (_a.minor < _b.minor) return -1;else if (_a.patch > _b.patch) return 1;else if (_a.patch < _b.patch) return -1;else if (_a.build > _b.build) return 1;else if (_a.build < _b.build) return -1;else return 0;
}

var MessageQueue = function () {
	function MessageQueue() {
		_classCallCheck(this, MessageQueue);

		this.container = [];
	}

	MessageQueue.prototype.push = function push(elem) {
		this.container.push(elem);
	};

	MessageQueue.prototype.pop = function pop() {
		return this.container.pop();
	};

	MessageQueue.prototype.length = function length() {
		return this.container.length;
	};

	MessageQueue.prototype.isEmpty = function isEmpty() {
		return this.container.length === 0;
	};

	return MessageQueue;
}();

var DevicePoller = function () {
	function DevicePoller(device) {
		_classCallCheck(this, DevicePoller);

		this.device = device;
		this.timer = undefined;
		this.stop = false;
		this.modified = false;

		this.poll = this.poll.bind(this);
		this.get_servicetype = this.get_servicetype.bind(this);
		this.handle_servicetype = this.handle_servicetype.bind(this);
		this.get_update_model_name = this.get_update_model_name.bind(this);
		this.handle_update_model_name = this.handle_update_model_name.bind(this);
		this.change_to_netiofirmwareupdate = this.change_to_netiofirmwareupdate.bind(this);
		this.get_device_name = this.get_device_name.bind(this);
		this.handle_device_name = this.handle_device_name.bind(this);
		this.get_model_name = this.get_model_name.bind(this);
		this.handle_model_name = this.handle_model_name.bind(this);
		this.get_firmware_version = this.get_firmware_version.bind(this);
		this.handle_firmware_version = this.handle_firmware_version.bind(this);
		this.get_host_type = this.get_host_type.bind(this);
		this.handle_host_type = this.handle_host_type.bind(this);
		this.get_driver_version = this.get_driver_version.bind(this);
		this.handle_driver_version = this.handle_driver_version.bind(this);
		this.get_connected_uids = this.get_connected_uids.bind(this);
		this.handle_connected_uids = this.handle_connected_uids.bind(this);
		this.maybe_render = this.maybe_render.bind(this);
		this.handle_error = this.handle_error.bind(this);
		this.poll_again = this.poll_again.bind(this);

		if (this.device.prefered_service_type() == 'netioswitch') {
			this.device.prefered_service_info().model = 'avbswitch';
		}

		this.poll();
	}

	DevicePoller.prototype.restart = function restart() {
		if (this.stop) {
			this.stop = false;
			this.poll();
		}
	};

	DevicePoller.prototype.release = function release() {
		this.stop = true;
		clearTimeout(this.timer);
		this.timer = undefined;
	};

	DevicePoller.prototype.get_servicetype = function get_servicetype() {
		var url = this.device.url() + 'servicetype';
		return send(url, 0);
	};

	DevicePoller.prototype.handle_servicetype = function handle_servicetype(r) {
		var servicetype = r;
		if (servicetype == 'netiofirmwareupdate' && this.device.prefered_service_type() == 'netiohost') {
			this.device.change_service_info('netiohost', 'netiofirmwareupdate');
			return this.get_update_model_name().then(this.handle_update_model_name).then(this.change_to_netiofirmwareupdate).then(function () {
				return Promise.reject();
			});
		}
	};

	DevicePoller.prototype.get_update_model_name = function get_update_model_name() {
		var url = this.device.url() + this.device.uid + '/update/model_name';
		return send(url, 0);
	};

	DevicePoller.prototype.handle_update_model_name = function handle_update_model_name(r) {
		var model = r;
		if (this.device.prefered_service_info().model != model) {
			this.modified = true;
			this.device.prefered_service_info().model = model;
			this.device.prefered_service_info().name = model + ' in firmware update mode';
			this.device.prefered_service_info().fw = '0.0.0';
		}
	};

	DevicePoller.prototype.change_to_netiofirmwareupdate = function change_to_netiofirmwareupdate() {
		this.device.change_service_info('netiohost', 'netiofirmwareupdate');
	};

	DevicePoller.prototype.get_device_name = function get_device_name() {
		var url = this.device.url() + 'datastore/avb/' + this.device.uid + '/entity_name?client=' + clientID();
		return send(url, 0);
	};

	DevicePoller.prototype.handle_device_name = function handle_device_name(r) {
		var name = JSON.parse(r).value;
		if (this.device.prefered_service_info().name != name) {
			this.modified = true;
			this.device.prefered_service_info().name = name;
		}
	};

	DevicePoller.prototype.get_model_name = function get_model_name() {
		var url = this.device.url() + 'datastore/avb/' + this.device.uid + '/model_name?client=' + clientID();
		return send(url, 0);
	};

	DevicePoller.prototype.handle_model_name = function handle_model_name(r) {
		var model = JSON.parse(r).value;
		if (this.device.prefered_service_info().model != model) {
			this.modified = true;
			this.device.prefered_service_info().model = model;
		}
	};

	DevicePoller.prototype.get_firmware_version = function get_firmware_version() {
		var url = this.device.url();
		if (this.device.prefered_service_type() == 'netioswitch') url += 'firmware_version';else url += 'datastore/avb/' + this.device.uid + '/firmware_version?client=' + clientID();
		return send(url, 0);
	};

	DevicePoller.prototype.handle_firmware_version = function handle_firmware_version(r) {
		var fw = '';
		if (this.device.prefered_service_type() == 'netioswitch') fw = r.split('\n')[0];else fw = JSON.parse(r).value.split('\n')[0];
		if (this.device.prefered_service_info().fw != fw) {
			this.modified = true;
			this.device.prefered_service_info().fw = fw;
		}
	};

	DevicePoller.prototype.get_host_type = function get_host_type() {
		var url = this.device.url() + 'datastore/host_type?client=' + clientID();
		return send(url, 0).catch(function () {
			return JSON.stringify({ value: '0.0.0' });
		});
	};

	DevicePoller.prototype.handle_host_type = function handle_host_type(r) {
		var host_type = JSON.parse(r).value;
		if (this.device.prefered_service_info().host_type != host_type) {
			this.modified = true;
			this.device.prefered_service_info().host_type = host_type;
		}
	};

	DevicePoller.prototype.get_driver_version = function get_driver_version() {
		var url = this.device.url() + 'datastore/host/driver_version?client=' + clientID();
		return send(url, 0);
	};

	DevicePoller.prototype.handle_driver_version = function handle_driver_version(r) {
		var driver_version = JSON.parse(r).value;
		if (this.device.prefered_service_info().driver_version != driver_version) {
			this.modified = true;
			this.device.prefered_service_info().driver_version = driver_version;
		}
	};

	DevicePoller.prototype.get_connected_uids = function get_connected_uids() {
		var url = this.device.url() + 'datastore/avb/devs?client=' + clientID();
		return send(url, 0);
	};

	DevicePoller.prototype.handle_connected_uids = function handle_connected_uids(r) {
		var connected_uids = JSON.parse(r).value;
		connected_uids = connected_uids.split(':');
		var index = connected_uids.indexOf(this.device.uid);
		if (index != -1) {
			connected_uids.splice(index, 1);
			connected_uids = connected_uids.join(':');
		}
		if (this.device.prefered_service_info().connected_uids != connected_uids) {
			this.modified = true;
			this.device.prefered_service_info().connected_uids = connected_uids;
		}
	};

	DevicePoller.prototype.maybe_render = function maybe_render() {
		if (this.modified) {
			this.device.device_list.render();
			this.modified = false;
		}
	};

	DevicePoller.prototype.handle_error = function handle_error(svc_type) {
		console.log('Error: ' + this.device.uid);
		if (!this.stop) {
			this.release();
			queue.push(JSON.stringify({ method: "delService", args: [this.device.uid, svc_type] }));
		}
	};

	DevicePoller.prototype.poll_again = function poll_again() {
		if (!this.stop) this.timer = setTimeout(this.poll, 15000);
	};

	DevicePoller.prototype.poll = function poll() {
		var _this = this;

		var svc_type = this.device.prefered_service_type();
		this.anyChanges = false;

		if (svc_type == 'netioswitch') {
			this.get_firmware_version().then(this.handle_firmware_version).then(this.maybe_render).catch(function () {
				_this.handle_error(svc_type);
			});
		} else if (svc_type == 'netiofirmwareupdate') {
			this.get_servicetype().then(this.handle_servicetype).then(this.maybe_render).catch(function () {
				_this.device.device_list.remove(_this.device.uid, 'netiofirmwareupdate');
			});
		} else if (svc_type == 'netiohost' || svc_type == 'netiodevice') {
			this.get_servicetype().then(this.handle_servicetype).then(this.get_device_name).then(this.handle_device_name).then(this.get_model_name).then(this.handle_model_name).then(this.get_firmware_version).then(this.handle_firmware_version).then(this.get_host_type).then(this.handle_host_type).then(this.get_driver_version).then(this.handle_driver_version).then(this.get_connected_uids).then(this.handle_connected_uids).then(this.maybe_render).then(this.poll_again).catch(function () {
				_this.handle_error(svc_type);
			});
		}
	};

	return DevicePoller;
}();

var DeviceDiv = function DeviceDiv(device) {
	_classCallCheck(this, DeviceDiv);

	this.device = device;
	this.div = document.createElement('div');
};

var DeviceIcon = function (_DeviceDiv) {
	_inherits(DeviceIcon, _DeviceDiv);

	function DeviceIcon(device) {
		_classCallCheck(this, DeviceIcon);

		var _this2 = _possibleConstructorReturn(this, _DeviceDiv.call(this, device));

		_this2.div.className = 'deviceRowIcon';
		_this2.div.setAttribute('type', _this2.device.prefered_service_type());

		var model = _this2.device.prefered_service_info().model;
		if (model) {
			var motu_version = _this2.device.device_list.firmware_poller.get_latest_firmware_version(model);
			var device_version = _this2.device.prefered_service_info().fw;
			if (motu_version && device_version) {
				_this2.div.setAttribute('update', String(versionCompare(motu_version, device_version) > 0));
			}
		}
		return _this2;
	}

	return DeviceIcon;
}(DeviceDiv);

var HostConnectionIcon = function (_DeviceDiv2) {
	_inherits(HostConnectionIcon, _DeviceDiv2);

	function HostConnectionIcon(device) {
		_classCallCheck(this, HostConnectionIcon);

		var _this3 = _possibleConstructorReturn(this, _DeviceDiv2.call(this, device));

		_this3.div.className = 'deviceRowHost';
		if ('netiohost' in _this3.device.service_info) {
			if (_this3.device.prefered_service_info().host_type == 'Thunderbolt') _this3.div.className += ' thunderbolt';else _this3.div.className += ' usb';
		}
		return _this3;
	}

	return HostConnectionIcon;
}(DeviceDiv);

var DeviceName = function (_DeviceDiv3) {
	_inherits(DeviceName, _DeviceDiv3);

	function DeviceName(device) {
		_classCallCheck(this, DeviceName);

		var _this4 = _possibleConstructorReturn(this, _DeviceDiv3.call(this, device));

		_this4.div.className = 'deviceRowName';
		_this4.div.innerHTML = _this4.device.prefered_service_info().name;
		return _this4;
	}

	return DeviceName;
}(DeviceDiv);

var ControlAppButton = function (_DeviceDiv4) {
	_inherits(ControlAppButton, _DeviceDiv4);

	function ControlAppButton(device) {
		_classCallCheck(this, ControlAppButton);

		var _this5 = _possibleConstructorReturn(this, _DeviceDiv4.call(this, device));

		_this5.div.className = 'btn launchCtrlApp parentHover';
		var onclickString = "launchCtrlApp('" + _this5.device.url() + "')";
		_this5.div.setAttribute('onclick', onclickString);
		return _this5;
	}

	return ControlAppButton;
}(DeviceDiv);

var Device = function () {
	function Device(uid, device, device_list) {
		_classCallCheck(this, Device);

		this.uid = uid;
		this.service_info = device;
		this.device_list = device_list;
		this.poller = new DevicePoller(this);
		this.render = this.render.bind(this);
		this.div = document.createElement('div');
		this.div.className = 'deviceRow';
	}

	Device.prototype.release = function release() {
		this.poller.release();
	};

	Device.prototype.prefered_service_type = function prefered_service_type() {
		if ('netiodevice' in this.service_info) return 'netiodevice';else return Object.keys(this.service_info)[0];
	};

	Device.prototype.prefered_service_info = function prefered_service_info() {
		return this.service_info[this.prefered_service_type()];
	};

	Device.prototype.url = function url() {
		var isProxy = this.prefered_service_type() == 'netiohost';
		var isProxy = isProxy || this.prefered_service_info().port.indexOf('/') != -1;
		var url = 'http://' + this.prefered_service_info().address + ':' + this.prefered_service_info().port + (isProxy ? '/' + this.uid : '') + '/';
		return url;
	};

	Device.prototype.change_service_info = function change_service_info(oldtype, newtype) {
		if (oldtype in this.service_info) {
			this.service_info[newtype] = this.service_info[oldtype];
			this.remove_service_info(oldtype);
		}
	};

	Device.prototype.remove_service_info = function remove_service_info(netiotype) {
		if (netiotype in this.service_info) {
			delete this.service_info[netiotype];
			this.poller.release();
			if (Object.keys(this.service_info).length) {
				this.poller = new DevicePoller(this);
			}
		}
		return Object.keys(this.service_info).length;
	};

	Device.prototype.render = function render() {
		var ui = [new DeviceIcon(this), new HostConnectionIcon(this), new DeviceName(this), new ControlAppButton(this)];
		this.div.innerHTML = '';
		for (var i = 0; i < ui.length; ++i) {
			this.div.appendChild(ui[i].div);
		}
	};

	return Device;
}();

var UDPDevice = function () {
	function UDPDevice(msg, device_list) {
		_classCallCheck(this, UDPDevice);

		this.uid = msg.uid;
		this.service_info = { netioswitch: { address: msg.ip, fw: msg.version, local: false, model: msg.model, name: msg.name, port: 80 } };
		this.device_list = device_list;
		this.remove = this.remove.bind(this);
		this.render = this.render.bind(this);
		this.div = document.createElement('div');
		this.div.className = 'deviceRow';
		this.start_timeout();
		this.device_list.render();
	}

	UDPDevice.prototype.remove = function remove() {
		this.device_list.remove_now(this.uid);
	};

	UDPDevice.prototype.start_timeout = function start_timeout() {
		this.timeout = window.setTimeout(this.remove, 20000);
	};

	UDPDevice.prototype.handle_announce = function handle_announce(msg) {
		window.clearTimeout(this.timeout);
		this.start_timeout();

		var render = false;
		var info = this.service_info.netioswitch;

		if (msg.ip != info.address) {
			info.address = msg.ip;
			render = true;
		}
		if (msg.version != info.fw) {
			info.fw = msg.version;
			render = true;
		}
		if (msg.name != info.name) {
			info.name = msg.name;
			render = true;
		}
		if (render) {
			this.device_list.render();
		}
	};

	UDPDevice.prototype.prefered_service_type = function prefered_service_type() {
		return Object.keys(this.service_info)[0];
	};

	UDPDevice.prototype.prefered_service_info = function prefered_service_info() {
		return this.service_info[this.prefered_service_type()];
	};

	UDPDevice.prototype.url = function url() {
		var url = 'http://' + this.prefered_service_info().address + ':' + this.prefered_service_info().port + '/';
		return url;
	};

	UDPDevice.prototype.render = function render() {
		var ui = [new DeviceIcon(this), new HostConnectionIcon(this), new DeviceName(this), new ControlAppButton(this)];
		this.div.innerHTML = '';
		for (var i = 0; i < ui.length; ++i) {
			this.div.appendChild(ui[i].div);
		}
	};

	return UDPDevice;
}();

var NewFirmwarePoller = function () {
	function NewFirmwarePoller(device_list) {
		_classCallCheck(this, NewFirmwarePoller);

		this.device_list = device_list;
		this.families = [{ models: ['8M', '16A', '1248', '112D'], latest: 0 }, { models: ['24Ai', '24Ao', 'Monitor 8'], latest: 0 }, { models: ['UltraLite AVB', 'UltraLite AVB ES', 'Stage-B16'], latest: 0 }, { models: ['avbswitch'], latest: 0 }, { models: ['UltraLite-mk4', 'UltraLite-mk4 ES'], latest: 0 }, { models: ['8A', '624'], latest: 0 }, { models: ['M64', 'LP32', '8D'], latest: 0 }, { models: ['828ES', '8PreES'], latest: 0 }, { models: ['driver'], latest: 0 }, { models: ['driver-win'], latest: 0 }, { models: ['avbswitch2'], latest: 0 }];
		var families = this.families;
		var funcs = [];
		for (var i in families) {
			var lower = encodeURIComponent(families[i].models[0].toLowerCase());
			var url = 'http://firmware.motu.com/api/device/' + lower + '/firmware';
			(function (url, i) {
				funcs.push(function () {
					return send(url, 0);
				});
				funcs.push(function (r) {
					var j = JSON.parse(r);if (j.length) families[i].latest = j[0];
				});
			})(url, i);
		}
		funcs.push(function () {
			return device_list.render();
		});
		funcs.reduce(function (prev, cur) {
			return prev.then(cur);
		}, Promise.resolve());
		this.get_latest_firmware = this.get_latest_firmware.bind(this);
		this.get_latest_firmware_version = this.get_latest_firmware_version.bind(this);
	}

	NewFirmwarePoller.prototype.get_latest_firmware = function get_latest_firmware(model) {
		for (var i in this.families) {
			if (this.families[i].models.indexOf(model) > -1) return this.families[i].latest;
		}
	};

	NewFirmwarePoller.prototype.get_latest_firmware_version = function get_latest_firmware_version(model) {
		var latest = this.get_latest_firmware(model);
		if (latest) return latest.version;
	};

	return NewFirmwarePoller;
}();

var LocalDeviceView = function () {
	function LocalDeviceView(deviceList) {
		_classCallCheck(this, LocalDeviceView);

		this.deviceList = deviceList;
		this.devices = deviceList.devices;
		this.updates = deviceList.firmware_poller;
		this.render = this.render.bind(this);
		this.next = this.next.bind(this);
		this.index = 0;
		this.localUIDs = [];
	}

	LocalDeviceView.prototype._get_next = function _get_next() {
		return (this.index + 1) % this.localUIDs.length;
	};

	LocalDeviceView.prototype.next = function next() {
		this.index = this._get_next();
		this.render();
	};

	LocalDeviceView.prototype.render = function render() {
		var _this6 = this;

		this.localUIDs = [];
		var localModels = [];
		for (var uid in this.devices) {
			if ('netiohost' in this.devices[uid].service_info && this.devices[uid].service_info['netiohost'].local) {
				this.localUIDs.push(uid);
				localModels.push(this.devices[uid].prefered_service_info().model);
			}
		}

		if (this.localUIDs.length) {
			if (this.index >= this.localUIDs.length) this.index = 0;

			var info = this.devices[this.localUIDs[this.index]].prefered_service_info();

			if (info.model == undefined || info.driver_version == undefined || info.fw == undefined || info.connected_uids == undefined) return;

			if (info.connected_uids) {
				info.connected_uids.split(':').map(function (uid) {
					if (!(uid in _this6.devices)) {
						if (isMOTUUID(uid)) {
							var address = _this6.devices[_this6.localUIDs[_this6.index]].service_info['netiohost'].address;
							var server = _this6.devices[_this6.localUIDs[_this6.index]].service_info['netiohost'].server;
							var port = _this6.devices[_this6.localUIDs[_this6.index]].service_info['netiohost'].port + '/' + _this6.localUIDs[_this6.index];
							_this6.deviceList.add(uid, { netiodevice: { name: uid, address: address, server: server, port: port, local: false } });
						}
					}
				});
			}

			document.getElementById('rightPane').className = 'rightPane';
			var next_info = this.devices[this.localUIDs[this._get_next()]].prefered_service_info();
			var driver_update_version = this.updates.get_latest_firmware_version('driver');
			var firmware_update_version = this.updates.get_latest_firmware_version(info.model);
			var host_type = 'usb';

			if (info.host_type == 'Thunderbolt') host_type = 'thunderbolt';

			document.getElementById('connectedDevice').setAttribute('uid', this.localUIDs[this.index]);
			document.getElementById('connectedDeviceImage').setAttribute('model', info.model);
			document.getElementById('connectedDeviceName').innerHTML = info.name;
			document.getElementById('deviceConnectedBy').setAttribute('connection', host_type);
			document.getElementById('driverVersion').innerHTML = info.driver_version;
			document.getElementById('firmwareVersion').innerHTML = info.fw;
			document.getElementById('driverUpdateVersion').innerHTML = driver_update_version;
			document.getElementById('firmwareUpdateVersion').innerHTML = firmware_update_version;

			if (versionCompare(driver_update_version, info.driver_version) > 0) {
				document.getElementById('driverUpdateVersion').style.display = '';
				document.getElementById('driverUpdateVersionLabel').style.display = '';
			} else {
				document.getElementById('driverUpdateVersion').style.display = 'none';
				document.getElementById('driverUpdateVersionLabel').style.display = 'none';
			}

			if (versionCompare(firmware_update_version, info.fw) > 0) {
				document.getElementById('firmwareUpdateVersionLabel').style.display = '';
				document.getElementById('firmwareUpdateVersion').style.display = '';
				document.getElementById('firmwareUpdateAvailable').style.display = '';
			} else {
				document.getElementById('firmwareUpdateVersionLabel').style.display = 'none';
				document.getElementById('firmwareUpdateVersion').style.display = 'none';
				document.getElementById('firmwareUpdateAvailable').style.display = 'none';
			}
			document.getElementById('nextDeviceName').innerHTML = next_info.name;

			if (document.getElementById('rightPane').getAttribute('tab') == 0) setLoading(false);
		} else {
			document.getElementById('rightPane').className = 'rightPane noDevice';
		}

		if (this.localUIDs.length > 1 && next_info.model != undefined) document.getElementById('multipleDevices').style.display = '';else document.getElementById('multipleDevices').style.display = 'none';
	};

	return LocalDeviceView;
}();

var DeviceList = function () {
	function DeviceList() {
		_classCallCheck(this, DeviceList);

		this.filter = '';
		this.hide_switches = false;
		this.devices = {};
		this.firmware_poller = new NewFirmwarePoller(this);
		this.local_view = new LocalDeviceView(this);
		this._render = this._render.bind(this);
		this.render = debounce(this._render, this, 100);
		this.render_observer = undefined;
		this.pending_remove = {};
		queue.push(JSON.stringify({ method: "getDeviceList", args: null }));
	}

	DeviceList.prototype.change = function change() {
		queue.push(JSON.stringify({ method: "getDeviceList", args: null }));
	};

	DeviceList.prototype.set_render_observer = function set_render_observer(observer) {
		this.render_observer = observer;
	};

	DeviceList.prototype.set = function set(devices) {
		for (var uid in devices) {
			this.add(uid, devices[uid]);
		}this.render();
	};

	DeviceList.prototype.add = function add(uid, device) {
		if (uid in this.pending_remove) {
			clearTimeout(this.pending_remove[uid]);
			delete this.pending_remove[uid];
		}
		if (this.devices[uid] != undefined) this.devices[uid].release();
		this.devices[uid] = new Device(uid, device, this);
		this.render();
	};

	DeviceList.prototype.handle_udp_announce = function handle_udp_announce(msg) {
		try {
			msg = JSON.parse(msg);
			if ('uid' in msg && 'model' in msg && msg.model == 'avbswitch2') {
				if (this.devices[msg.uid] == undefined) this.devices[msg.uid] = new UDPDevice(msg, this);else this.devices[msg.uid].handle_announce(msg);
			}
		} catch (e) {}
	};

	DeviceList.prototype.remove = function remove(uid, netiotype) {
		if (this.devices[uid] != undefined) {
			var self = this;
			self.pending_remove[uid] = setTimeout(function () {
				delete self.pending_remove[uid];
				if (self.devices[uid].remove_service_info(netiotype) == 0) {
					self.devices[uid].release();
					delete self.devices[uid];
				}
				self.render();
			}, 1000);
		}
	};

	DeviceList.prototype.remove_now = function remove_now(uid) {
		if (this.devices[uid] != undefined) {
			delete this.devices[uid];
			this.render();
		}
	};

	DeviceList.prototype.set_filter = function set_filter(filter) {
		this.filter = filter;
		this.render();
	};

	DeviceList.prototype._render = function _render() {
		var parentNode = document.getElementById('deviceList');

		if (parentNode == undefined) return;

		parentNode.innerHTML = '';

		if (this.render_observer) this.render_observer.update();

		this.local_view.render();

		var devs = {};
		if (this.filter) {
			for (var uid in this.devices) {
				var info = this.devices[uid].prefered_service_info();
				if (info.name.toLowerCase().indexOf(this.filter.toLowerCase()) != -1) {
					devs[uid] = this.devices[uid];
				}
			}
		} else {
			devs = this.devices;
		}

		var sorted = Object.keys(devs).sort(function (a, b) {
			if (devs[a].prefered_service_info()['name'] < devs[b].prefered_service_info()['name']) return -1;
			if (devs[a].prefered_service_info()['name'] > devs[b].prefered_service_info()['name']) return 1;
			return 0;
		});
		for (var i = 0; i < sorted.length; ++i) {
			if (this.hide_switches && devs[sorted[i]].prefered_service_type() == 'netioswitch') continue;
			devs[sorted[i]].render();
			parentNode.appendChild(devs[sorted[i]].div);
		}
		document.getElementById('numberOfDevices').innerHTML = '(' + Object.keys(this.devices).length + ')';
	};

	return DeviceList;
}();

var queue = new MessageQueue();
var devices = new DeviceList();

function poll() {
	if (!queue.isEmpty()) return queue.pop();
	return undefined;
}

function clear() {
	while (!queue.isEmpty()) {
		queue.pop();
	}
}

function paneSelect(e) {
	var target = e.target;
	if (e.target.nodeName.toLowerCase() == 'span') target = e.target.parentNode;
	var rightPane = document.getElementById('rightPane');
	var value = target.getAttribute('value');
	var oldValue = rightPane.getAttribute('tab');

	if (oldValue == 0) {
		document.getElementById('mainWrapper').setAttribute('loading', 'false');
	}

	if (value == 4) {
		document.getElementById('virtualEntityCheckboxContainer').innerHTML = 'Loading . . .';
		queue.push(JSON.stringify({ method: "getAVBInterfaces", args: null }));
	}

	target.parentNode.setAttribute('value', value);
	rightPane.setAttribute('tab', value);
}

function nextDevice() {
	devices.local_view.next();
}

function launchCtrlAppLocal() {
	var uid = document.getElementById('connectedDevice').getAttribute('uid');
	var url = 'http://localhost:1280/' + uid + '/';
	launchCtrlApp(url);
}

function launchCtrlApp(url) {
	queue.push(JSON.stringify({ method: "launchCtrlApp", args: url }));
}

function hideSwitches(e) {
	var value = e.target.getAttribute('value');
	if (value == '0') {
		e.target.setAttribute('value', '1');
		document.cookie = "motu_hide_switches=true; expires=Fri, 31 Dec 9999 23:59:59 GMT";
		devices.hide_switches = true;
	} else {
		e.target.setAttribute('value', '0');
		document.cookie = "motu_hide_switches=false; expires=Fri, 31 Dec 9999 23:59:59 GMT";
		devices.hide_switches = false;
	}
	devices.render();
}

function showInMenuBar(e) {
	var value = e.target.getAttribute('value');
	if (value == '0') {
		e.target.setAttribute('value', '1');
		queue.push(JSON.stringify({ method: "showInMenuBar", args: true }));
	} else {
		e.target.setAttribute('value', '0');
		queue.push(JSON.stringify({ method: "showInMenuBar", args: false }));
	}
}

function setIsInMenuBar(value) {
	var target = document.getElementById('showInMenuBar');
	if (value) target.setAttribute('value', '1');else target.setAttribute('value', '0');
}

function setAVBInterfaces(ifaces) {
	var parent = document.getElementById('virtualEntityCheckboxContainer');
	parent.innerHTML = '';
	if (Object.keys(ifaces).length == 0) {
		var row = document.createElement('div');
		var checkbox = document.createElement('div');
		var label = document.createElement('div');
		checkbox.className = 'checkbox';
		checkbox.style.pointerEvents = 'none';
		row.className = 'virtualEntityRow';
		label.className = 'checkboxLabel';
		label.innerHTML = 'No AVB network interfaces found';
		row.appendChild(checkbox);
		row.appendChild(label);
		row.style.opacity = '0.6';
		parent.appendChild(row);
	}
	for (var iface in ifaces) {
		var row = document.createElement('div');
		var checkbox = document.createElement('div');
		var label = document.createElement('div');
		checkbox.className = 'checkbox';
		checkbox.setAttribute('value', ifaces[iface].enabled ? '1' : '0');
		checkbox.id = iface;
		checkbox.onclick = function (e) {
			var value = e.target.getAttribute('value');
			if (value == '0') {
				e.target.setAttribute('value', '1');
				document.getElementById('spinnerText').innerHTML = 'Enabling Virtual Audio Entity...';
				queue.push(JSON.stringify({ method: "enableVirtualEntity", args: e.target.id }));
			} else {
				e.target.setAttribute('value', '0');
				queue.push(JSON.stringify({ method: "disableVirtualEntity", args: e.target.id }));
			}
		};
		label.className = 'checkboxLabel';
		label.innerHTML = ifaces[iface].name + ' - ' + iface;
		row.className = 'virtualEntityRow';
		row.appendChild(checkbox);
		row.appendChild(label);
		parent.appendChild(row);
	}
}

function setLoading(value) {
	document.getElementById('mainWrapper').setAttribute('loading', value);
}

function getCookie(name) {
	var match = document.cookie.match(new RegExp(name + '=([^;]+)'));
	if (match) return match[1];
}

window.onload = function () {

	var hide_switches = getCookie('motu_hide_switches');

	if (hide_switches && hide_switches == 'true') {
		document.getElementById('hideSwitchesCheckbox').setAttribute('value', '1');
		devices.hide_switches = true;
	} else {
		document.getElementById('hideSwitchesCheckbox').setAttribute('value', '0');
		devices.hide_switches = false;
	}

	if (window.navigator.appVersion.indexOf('OS X 10_8') != -1 || window.navigator.appVersion.indexOf('OS X 10_9') != -1) {
		document.getElementById('advancedTab').style.display = 'none';
		document.getElementById('deviceList').setAttribute('flex', 'false');
	}

	// We no longer support the avb virtual enable
	document.getElementById('virtualEntity').style.display = 'none';

	devices.render();
	queue.push(JSON.stringify({ method: "isInMenuBar", args: null }));

	var search = document.getElementById('deviceSearch');
	search.oninput = function (e) {
		devices.set_filter(e.target.value);
	};
	document.getElementById('spinnerText').innerHTML = 'Searching for Local Devices...';
	setTimeout(function () {
		return document.getElementById('mainWrapper').setAttribute('loading', 'false');
	}, 5000);
};
