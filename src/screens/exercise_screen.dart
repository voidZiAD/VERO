import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../services/block_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum ExerciseType { pushups, squats, pullups, planks } 
enum ExerciseState { setup, countdown, detecting, congrats }

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with SingleTickerProviderStateMixin {
  ExerciseState _state = ExerciseState.setup;
  ExerciseType _selectedExercise = ExerciseType.pushups;
  int _targetReps = 10;
  int _breakMinutes = 5;
  int _countdown = 3;
  
  int _plankTargetSeconds = 30;
  int _currentPlankSeconds = 30;
  Timer? _plankTimer;
  bool _isPlankCorrect = false;
  
  CameraController? _controller;
  late PoseDetector _poseDetector;
  bool _isDetecting = false;
  List<Pose> _poses = [];

  int _currentReps = 0;
  bool _isDown = false; 
  bool _isUp = false;
  double _smoothAngle = 180.0; 
  final double _alpha = 0.2; 
  double _imageWidth = 1.0;
  double _imageHeight = 1.0;

  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); 
    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
    _confettiController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _calculateBreakTime();
  }

  void _calculateBreakTime() {
    setState(() {
      if (_selectedExercise == ExerciseType.planks) {
        _breakMinutes = (_plankTargetSeconds / 6).ceil().clamp(1, 25);
      } else {
        _breakMinutes = (_targetReps / 2).ceil().clamp(1, 25);
      }
    });
  }

  Future<void> _startExercise() async {
    await _initCamera();
    setState(() {
      _state = ExerciseState.countdown;
      _countdown = 3;
      _currentReps = 0;
      if (_selectedExercise == ExerciseType.planks) {
        _currentPlankSeconds = _plankTargetSeconds;
        _isPlankCorrect = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _state = ExerciseState.detecting;
          timer.cancel();
          if (_selectedExercise == ExerciseType.planks) {
            _startPlankTimer();
          }
        }
      });
    });
  }

  void _startPlankTimer() {
    _plankTimer?.cancel();
    _plankTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _state != ExerciseState.detecting) {
        timer.cancel();
        return;
      }
      
      if (_isPlankCorrect) {
        setState(() {
          if (_currentPlankSeconds > 0) {
            _currentPlankSeconds--;
          } else {
            _finishExercise();
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_isDetecting || _state != ExerciseState.detecting) return;
      _isDetecting = true;

      if (Platform.isAndroid) {
        _imageWidth = image.height.toDouble();
        _imageHeight = image.width.toDouble();
      } else {
        _imageWidth = image.width.toDouble();
        _imageHeight = image.height.toDouble();
      }

      await _processCameraImage(image);
      _isDetecting = false;
    });

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final InputImage? inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    final poses = await _poseDetector.processImage(inputImage);
    if (!mounted) return;
    setState(() => _poses = poses);
    _countReps(poses);
  }

  void _countReps(List<Pose> poses) {
    if (poses.isEmpty) {
      if (_selectedExercise == ExerciseType.planks) {
        _isPlankCorrect = false;
      }
      return;
    }
    final pose = poses.first;

    switch (_selectedExercise) {
      case ExerciseType.pushups: _detectPushups(pose); break;
      case ExerciseType.squats: _detectSquats(pose); break;
      case ExerciseType.pullups: _detectPullups(pose); break;
      case ExerciseType.planks: _detectPlank(pose); break;
    }

    if (_selectedExercise != ExerciseType.planks && _currentReps >= _targetReps) {
      _finishExercise();
    }
  }

  void _detectPushups(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (shoulder == null || elbow == null || wrist == null || nose == null) return;
    if (shoulder.likelihood < 0.5 || elbow.likelihood < 0.5) return;

    final rawAngle = _getAngle(shoulder, elbow, wrist);
    _smoothAngle = (_smoothAngle * (1 - _alpha)) + (rawAngle * _alpha);

    double midArmY = (shoulder.y + elbow.y) / 2;
    bool isNoseLow = nose.y > midArmY; 

    if (_smoothAngle < 155 && isNoseLow) _isDown = true;
    if (_smoothAngle > 165 && _isDown) {
      _currentReps++;
      _isDown = false;
    }
  }

  void _detectSquats(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (hip == null || knee == null || ankle == null) return;
    if (hip.likelihood < 0.6 || knee.likelihood < 0.6 || ankle.likelihood < 0.6) return;

    final rawAngle = _getAngle(hip, knee, ankle);
    _smoothAngle = (_smoothAngle * (1 - _alpha)) + (rawAngle * _alpha);

    if (_smoothAngle < 90) _isDown = true;
    if (_smoothAngle > 165 && _isDown) {
      _currentReps++;
      _isDown = false;
    }
  }

  void _detectPullups(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];

    if (shoulder == null || elbow == null || wrist == null) return;
    if (shoulder.likelihood < 0.5 || elbow.likelihood < 0.5 || wrist.likelihood < 0.5) return;
    
    if (wrist.y > shoulder.y) return; 

    final rawAngle = _getAngle(shoulder, elbow, wrist);
    _smoothAngle = (_smoothAngle * (1 - _alpha)) + (rawAngle * _alpha);

    if (_smoothAngle < 80) {
      _isUp = true;
    }
    
    if (_smoothAngle > 160 && _isUp) {
      _currentReps++;
      _isUp = false;
    }
  }

  void _detectPlank(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    // Basic visibility check: We need at least shoulders and elbows to verify support
    if (leftShoulder == null || rightShoulder == null || 
        leftElbow == null || rightElbow == null) {
      _isPlankCorrect = false;
      return;
    }

    // Calculate average Y positions (Note: In image coordinates, Y increases downwards)
    // So "Above" means a LOWER Y value.
    double avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double avgElbowY = (leftElbow.y + rightElbow.y) / 2;
    
    // Check 1: Arms Support
    // Shoulders must be higher (lower Y) than elbows. 
    // We add a small buffer (20px) to handle slight camera tilts.
    bool armsSupporting = avgShoulderY < (avgElbowY - 20); 

    // Check 2: Body Prone
    // If hips are visible, they should be lower (higher Y) than shoulders.
    // This prevents standing up or sitting down from counting.
    bool bodyProne = true;
    if (leftHip != null && rightHip != null && leftHip.likelihood > 0.5 && rightHip.likelihood > 0.5) {
       double avgHipY = (leftHip.y + rightHip.y) / 2;
       bodyProne = avgHipY > avgShoulderY;
    }

    // Update angle for display purposes only (don't use it for pass/fail)
    if (leftShoulder != null && leftHip != null) {
       final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
       if (leftAnkle != null) {
          double angle = _getAngle(leftShoulder, leftHip, leftAnkle);
          _smoothAngle = (_smoothAngle * (1 - _alpha)) + (angle * _alpha);
       }
    }

    // SIMPLIFIED LOGIC:
    // If your arms are on the ground supporting you, and your body is below your shoulders, you are planking.
    if (armsSupporting && bodyProne) {
      _isPlankCorrect = true;
    } else {
      _isPlankCorrect = false;
    }
  }

  String _getGuidanceText() {
    switch (_selectedExercise) {
      case ExerciseType.pushups:
        return "Position phone on the floor, side view.\nFull plank position.";
      case ExerciseType.squats:
        return "Position phone at knee height, side view.\nStand fully upright to start.";
      case ExerciseType.pullups:
        return "Position phone at chest height.\nEnsure hands are visible above head.";
      case ExerciseType.planks:
        // Updated guidance
        return "Position phone on floor.\nFront or Side view.\nKeep shoulders above elbows.";
    }
  }


  void _finishExercise() {
    _controller?.stopImageStream();
    _plankTimer?.cancel(); 
    HapticFeedback.heavyImpact();
    setState(() {
      _state = ExerciseState.congrats;
    });
    _confettiController.forward();
  }

  Future<void> _activateBreak() async {
    await BlockService().snooze(_breakMinutes);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  double _getAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    double result = math.atan2(last.y - mid.y, last.x - mid.x) -
                    math.atan2(first.y - mid.y, first.x - mid.x);
    result = result * (180 / math.pi);
    result = result.abs();
    if (result > 180) result = 360.0 - result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
             child: Container(
               decoration: const BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topCenter, end: Alignment.bottomCenter,
                   colors: [Color(0xFF120520), Colors.black],
                 ),
               ),
             ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("VERO", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 28, color: Colors.white)),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: _state == ExerciseState.setup 
                    ? _buildSetupScreen()
                    : (_state == ExerciseState.detecting || _state == ExerciseState.countdown) 
                      ? _buildDetectionScreen()
                      : _buildCongratsScreen(),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildSetupScreen() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("EARN YOUR BREAK", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 32, color: Colors.white)),
          const SizedBox(height: 10),
          Text("Complete an exercise to unlock your apps for $_breakMinutes minutes.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 50),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ExerciseType>(
                value: _selectedExercise,
                dropdownColor: const Color(0xFF1A0B2E),
                isExpanded: true,
                items: ExerciseType.values.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )).toList(),
                onChanged: (v) {
                  setState(() => _selectedExercise = v!);
                  _calculateBreakTime();
                },
              ),
            ),
          ),
          const SizedBox(height: 30),

          Text(_selectedExercise == ExerciseType.planks ? "DURATION" : "REPS GOAL", style: const TextStyle(color: Colors.purpleAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _selectedExercise == ExerciseType.planks ? "$_plankTargetSeconds s" : "$_targetReps", 
                style: const TextStyle(fontSize: 60, fontFamily: 'DxSitrus', color: Colors.white)
              ),
            ],
          ),
          
          if (_selectedExercise == ExerciseType.planks)
            Slider(
              value: _plankTargetSeconds.toDouble(),
              min: 15, max: 120, divisions: 21, 
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) {
                if (v.toInt() != _plankTargetSeconds) HapticFeedback.selectionClick(); 
                setState(() => _plankTargetSeconds = v.toInt());
                _calculateBreakTime(); 
              },
            )
          else
            Slider(
              value: _targetReps.toDouble(),
              min: 6, max: 50, divisions: 44,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) {
                if (v.toInt() != _targetReps) HapticFeedback.selectionClick(); 
                setState(() => _targetReps = v.toInt());
                _calculateBreakTime(); 
              },
            ),
            
          const SizedBox(height: 50),

          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _startExercise();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text("START EXERCISE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildDetectionScreen() {
    if (_controller == null || !_controller!.value.isInitialized) return const Center(child: CircularProgressIndicator());
    
    if (_state == ExerciseState.countdown) {
      return Stack(
        children: [
          Positioned.fill(child: _buildCameraView()),
          Container(
            color: Colors.black54,
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$_countdown",
                  style: const TextStyle(
                    fontSize: 100,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DxSitrus'
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _getGuidanceText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      height: 1.5
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      );
    }

    String instruction = "";
    bool isCorrect = false;

    if (_selectedExercise == ExerciseType.planks) {
      instruction = _isPlankCorrect ? "HOLD" : "ALIGN BODY";
      isCorrect = _isPlankCorrect;
    } else if (_selectedExercise == ExerciseType.pullups) {
      instruction = _isUp ? "DOWN" : "PULL UP";
      isCorrect = _isUp;
    } else {
      instruction = _isDown ? "UP" : "GO DOWN";
      isCorrect = _isDown;
    }

    double progress = 0.0;
    if (_selectedExercise == ExerciseType.planks) {
      progress = 1.0 - (_currentPlankSeconds / _plankTargetSeconds);
    } else if (_selectedExercise == ExerciseType.squats) {
      progress = (170 - _smoothAngle) / (170 - 90);
    } else if (_selectedExercise == ExerciseType.pullups) {
      progress = (160 - _smoothAngle) / (160 - 70);
    } else {
      progress = (165 - _smoothAngle) / (165 - 140);
    }
    progress = progress.clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCameraView(),
                        
                        CustomPaint(
                          painter: PosePainter(
                            _poses,
                            _imageWidth,
                            _imageHeight,
                            _controller!.description.lensDirection,
                          ),
                        ),
                        Positioned(
                          right: 20, top: 50, bottom: 50,
                          child: Container(
                            width: 10,
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)),
                            child: FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.greenAccent : Colors.purpleAccent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Text(
                instruction,
                style: TextStyle(
                  color: isCorrect ? Colors.greenAccent : Colors.orangeAccent, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (_selectedExercise == ExerciseType.planks)
                    Text("$_currentPlankSeconds", style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold, fontFamily: 'DxSitrus'))
                  else
                    Text("$_currentReps", style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold, fontFamily: 'DxSitrus')),
                  
                  if (_selectedExercise == ExerciseType.planks)
                    const Text("s", style: TextStyle(color: Colors.grey, fontSize: 32, fontFamily: 'DxSitrus'))
                  else
                    Text("/$_targetReps", style: const TextStyle(color: Colors.grey, fontSize: 32, fontFamily: 'DxSitrus')),
                ],
              ),
              Text(
                "ANGLE: ${_smoothAngle.toStringAsFixed(0)}°", 
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCongratsScreen() {
    String message = "You did $_targetReps ${_selectedExercise.name}.";
    if (_selectedExercise == ExerciseType.planks) {
      message = "You held the plank for $_plankTargetSeconds seconds.";
    }

    return Stack(
      children: [
        CustomPaint(
          painter: ConfettiPainter(_confettiController),
          child: Container(),
        ),
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 100),
              const SizedBox(height: 30),
              const Text("CRUSHED IT!", style: TextStyle(fontFamily: 'DxSitrus', fontSize: 40, color: Colors.white)),
              const SizedBox(height: 10),
              Text("$message Enjoy your $_breakMinutes minute break.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)), 
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    _activateBreak();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: Text("UNBLOCK ($_breakMinutes MIN)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: format ?? InputImageFormat.nv21, bytesPerRow: plane.bytesPerRow),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    _poseDetector.close();
    _confettiController.dispose();
    _plankTimer?.cancel();
    super.dispose();
  }
}

class ConfettiPainter extends CustomPainter {
  final AnimationController controller;
  final List<ConfettiParticle> particles = [];

  ConfettiPainter(this.controller) : super(repaint: controller) {
    for (int i = 0; i < 50; i++) {
      particles.add(ConfettiParticle());
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      p.update(controller.value, size);
      paint.color = p.color;
      canvas.drawCircle(p.position, p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConfettiParticle {
  late Offset position;
  late Color color;
  late double size;
  late double speed;
  late double angle;

  ConfettiParticle() {
    final r = math.Random();
    position = const Offset(200, 200); 
    color = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple][r.nextInt(5)];
    size = r.nextDouble() * 5 + 2;
    speed = r.nextDouble() * 10 + 2;
    angle = r.nextDouble() * 2 * math.pi;
  }

  void update(double t, Size canvasSize) {
    double dx = math.cos(angle) * speed;
    double dy = math.sin(angle) * speed;
    position += Offset(dx, dy);
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final double imageWidth;
  final double imageHeight;
  final CameraLensDirection lensDirection;

  PosePainter(this.poses, this.imageWidth, this.imageHeight, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()..color = Colors.cyanAccent..strokeWidth = 6..style = PaintingStyle.fill;
    final linePaint = Paint()..color = Colors.purpleAccent..strokeWidth = 3;

    final double scale = math.max(size.width / imageWidth, size.height / imageHeight);
    final double offsetX = (size.width - (imageWidth * scale)) / 2;
    final double offsetY = (size.height - (imageHeight * scale)) / 2;

    for (final pose in poses) {
      Offset lm(PoseLandmarkType type) {
        final l = pose.landmarks[type];
        if (l == null || l.likelihood < 0.6) return Offset.zero;

        double x = l.x * scale + offsetX;
        double y = l.y * scale + offsetY;

        if (lensDirection == CameraLensDirection.front) {
          x = size.width - x; 
        }
        return Offset(x, y);
      }

      void drawConnection(PoseLandmarkType p1, PoseLandmarkType p2) {
        final o1 = lm(p1);
        final o2 = lm(p2);
        if (o1 != Offset.zero && o2 != Offset.zero) {
          canvas.drawLine(o1, o2, linePaint);
        }
      }

      drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawConnection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawConnection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      for (final landmark in pose.landmarks.values) {
        if (landmark.likelihood < 0.6) continue;
        double x = landmark.x * scale + offsetX;
        double y = landmark.y * scale + offsetY;
        if (lensDirection == CameraLensDirection.front) {
          x = size.width - x;
        }
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
