String.prototype.byChunk = function(size) {
	var re = new RegExp('.{1,' + size + '}', 'g');
	return this.match(re);
}

var sapguiData = {
	_data: [],
	_chunk: 0,

	set: function(str) {
		this._data = Base64.encode(str).byChunk(768);
		this.rewind();
	},

	rewind: function() {
		this._chunk = -1;
		var len = (this._data == null) ? 0 : this._data.length;
		window.history.pushState('', '', '#' + len);
	},

	next: function() {
		console.log("next");
		this._chunk++;
		this._setUrl();
	},

	_setUrl: function() {
		console.log("_setUrl");
		if (this._data == null || this._chunk >= this._data.length) {
			window.history.pushState('', '', '#');
		} else {
			window.history.pushState('', '', '#' + this._data[this._chunk]);
		}
		console.log("Location: " + window.location);
	}
}