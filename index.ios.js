/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 */
'use strict';

var React = require('react-native');
var {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  DeviceEventEmitter
} = React;

var BLE = require('NativeModules').BLE;

DeviceEventEmitter.addListener(
  'hrm',
  (data) => console.log(data)
);

DeviceEventEmitter.addListener('disconnect', () => BLE.scan());

BLE.scan();

var Ambulance = React.createClass({
  getInitialState: function() {
    return {
      bpm: 100,
      temp: 37,
    };
  },

  componentDidMount: function() {
    DeviceEventEmitter.addListener(
      'sensor',
      (data) => { console.log(data); this.setState(data) }
    );
  },

  render: function() {

    return (
      <View style={styles.container}>
        <View style={[styles.tile, {backgroundColor: this.getColor(100 - this.between(0, 100, Math.abs((37 - this.state.temp) * 10)))}]}>
          <Text style={styles.primary}>
            {this.state.temp} C°
          </Text>
          <Text style={styles.secondary}>
            {this.state.manufacturer ? 'from ' + this.state.manufacturer : 'not connected'}
          </Text>
        </View>
        <View style={[styles.tile, {backgroundColor: this.getColor(100 - this.between(0, 100, Math.abs(70 - this.state.bpm)))}]}>
          <Text style={styles.primary}>
            {this.state.bpm} BPM
          </Text>
          <Text style={styles.secondry}>
            {this.state.manufacturer ? 'from ' + this.state.manufacturer : 'not connected'}
          </Text>
        </View>
      </View>
    );
  },

  hslToRgb: function(h, s, l) {
    var r, g, b;

    if(s == 0){
      r = g = b = l; // achromatic
    } else {
      var hue2rgb = function hue2rgb(p, q, t){
        if(t < 0) t += 1;
        if(t > 1) t -= 1;
        if(t < 1/6) return p + (q - p) * 6 * t;
        if(t < 1/2) return q;
        if(t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      }

      var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      var p = 2 * l - q;
      r = hue2rgb(p, q, h + 1/3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1/3);
    }

    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
  },

  getColor: function(i) {
    // as the function expects a value between 0 and 1, and red = 0° and green = 120°
    // we convert the input to the appropriate hue value
    var hue = i * 1.2 / 360;
    // we convert hsl to rgb (saturation 100%, lightness 50%)
    var rgb = this.hslToRgb(hue, 1, .5);
    // we format to css value and return
    return 'rgb(' + rgb[0] + ',' + rgb[1] + ',' + rgb[2] + ')'; 
  },

  between: function(min, max, val) {
    return Math.max(min, Math.min(max, val));
  }
});

var styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'space-around',
    alignItems: 'stretch',
    backgroundColor: '#F5FCFF',
    margin: 5,
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  primary: {
    fontSize: 40,
    textAlign: 'center',
    color: '#333333',
  },
  secondary: {
    textAlign: 'center',
    color: '#333333',
  },
  tile: {
    height: 100,
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    margin: 10,
  }
});

AppRegistry.registerComponent('Ambulance', () => Ambulance);
