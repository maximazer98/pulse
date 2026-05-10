// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sr = 22050;

Uint8List wav(List<double> samples) {
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm[i] = v;
  }
  final dataLen = pcm.lengthInBytes;
  final bb = BytesBuilder();
  void wStr(String s) => bb.add(s.codeUnits);
  void wU32(int v) => bb.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  void wU16(int v) => bb.add([v & 0xff, (v >> 8) & 0xff]);
  wStr('RIFF');
  wU32(36 + dataLen);
  wStr('WAVE');
  wStr('fmt ');
  wU32(16);
  wU16(1);
  wU16(1);
  wU32(sr);
  wU32(sr * 2);
  wU16(2);
  wU16(16);
  wStr('data');
  wU32(dataLen);
  bb.add(pcm.buffer.asUint8List());
  return bb.toBytes();
}

double env(double t, double dur, {double atk = 0.003, double rel = 0.08}) {
  if (t < atk) return t / atk;
  final tailStart = dur - rel;
  if (t > tailStart) {
    final x = (dur - t) / rel;
    return (x * x).clamp(0.0, 1.0);
  }
  return 1.0;
}

double square(double phase) => sin(phase) >= 0 ? 1.0 : -1.0;
double saw(double phase) => (phase / pi) % 2 - 1;
double tri(double phase) {
  final p = (phase / (2 * pi)) % 1;
  return p < 0.5 ? 4 * p - 1 : 3 - 4 * p;
}

enum Wave { sine, square, saw, tri }

double _osc(Wave w, double phase) {
  switch (w) {
    case Wave.sine: return sin(phase);
    case Wave.square: return square(phase);
    case Wave.saw: return saw(phase);
    case Wave.tri: return tri(phase);
  }
}

List<double> osc(double dur, Wave w, double Function(double t) freqAt,
    {double atk = 0.003, double rel = 0.08, double amp = 0.5}) {
  final n = (sr * dur).round();
  final out = List<double>.filled(n, 0);
  double phase = 0;
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    phase += 2 * pi * freqAt(t) / sr;
    out[i] = _osc(w, phase) * env(t, dur, atk: atk, rel: rel) * amp;
  }
  return out;
}

List<double> noise(double dur, {double amp = 0.5, double atk = 0.002, double rel = 0.06, int seed = 42}) {
  final n = (sr * dur).round();
  final r = Random(seed);
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    out[i] = (r.nextDouble() * 2 - 1) * env(t, dur, atk: atk, rel: rel) * amp;
  }
  return out;
}

// Simple one-pole low-pass
List<double> lowpass(List<double> x, double cutoff) {
  final rc = 1 / (2 * pi * cutoff);
  final dt = 1 / sr;
  final a = dt / (rc + dt);
  final out = List<double>.filled(x.length, 0);
  double prev = 0;
  for (var i = 0; i < x.length; i++) {
    prev = prev + a * (x[i] - prev);
    out[i] = prev;
  }
  return out;
}

List<double> mix(List<List<double>> layers) {
  final n = layers.map((l) => l.length).reduce(max);
  final out = List<double>.filled(n, 0);
  for (final l in layers) {
    for (var i = 0; i < l.length; i++) {
      out[i] += l[i];
    }
  }
  final peak = out.map((v) => v.abs()).reduce(max);
  if (peak > 1) {
    for (var i = 0; i < n; i++) {
      out[i] /= peak;
    }
  }
  return out;
}

void main() {
  final outDir = Directory('assets/audio');
  outDir.createSync(recursive: true);

  // pass.wav — crisp synthwave blip: square + detuned saw, 880→1320 Hz, ~70ms
  final passSq = osc(0.07, Wave.square, (t) => 880 + 440 * (t / 0.07), amp: 0.35, rel: 0.05);
  final passSaw = osc(0.07, Wave.saw, (t) => 883 + 440 * (t / 0.07), amp: 0.22, rel: 0.05);
  final pass = lowpass(mix([passSq, passSaw]), 6000);
  File('${outDir.path}/pass.wav').writeAsBytesSync(wav(pass));

  // close.wav — bright arpeggio chirp: triangle sweep + sparkle noise, ~180ms
  final closeTri = osc(0.18, Wave.tri, (t) => 660 * pow(2, t * 5).toDouble(), amp: 0.55, rel: 0.12);
  final closeSq = osc(0.12, Wave.square, (t) => 1320 + 880 * (t / 0.12), amp: 0.3, rel: 0.08);
  final closeNoise = lowpass(noise(0.08, amp: 0.25, rel: 0.05, seed: 7), 8000);
  final close = mix([closeTri, closeSq, closeNoise]);
  File('${outDir.path}/close.wav').writeAsBytesSync(wav(close));

  // gameover.wav — detuned saw sweep down + crunch, ~500ms
  final goSaw1 = osc(0.5, Wave.saw, (t) => 330 * pow(2, -t * 2).toDouble(), amp: 0.55, rel: 0.3);
  final goSaw2 = osc(0.5, Wave.saw, (t) => 335 * pow(2, -t * 2).toDouble(), amp: 0.45, rel: 0.3);
  final goSq = osc(0.4, Wave.square, (t) => 165 * pow(2, -t * 2).toDouble(), amp: 0.35, rel: 0.25);
  final goNoise = lowpass(noise(0.45, amp: 0.4, rel: 0.3, seed: 13), 4000);
  final gameover = lowpass(mix([goSaw1, goSaw2, goSq, goNoise]), 5000);
  File('${outDir.path}/gameover.wav').writeAsBytesSync(wav(gameover));

  print('Wrote pass.wav (${File('${outDir.path}/pass.wav').lengthSync()}b), '
      'close.wav (${File('${outDir.path}/close.wav').lengthSync()}b), '
      'gameover.wav (${File('${outDir.path}/gameover.wav').lengthSync()}b)');
}
