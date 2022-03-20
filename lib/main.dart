import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/widgets.dart';
import 'package:test_flame/boundaries.dart';

void main() {
  final game = MyGame();
  runApp(GameWidget(game: game));
}

class MyGame extends Forge2DGame with MultiTouchDragDetector, HasTappables {
  MouseJoint? mouseJoint;
  static late BodyComponent grabbedBody;
  late Body groundBody;

  MyGame() : super(gravity: Vector2(0, -10.0));

  //Game onLoad
  @override
  Future<void> onLoad() async {
    final boundaries = createBoundaries(this); //Adding boundries
    boundaries.forEach(add);

    groundBody = world.createBody(BodyDef());

    add(Ball(screenToWorld(camera.viewport.effectiveSize / 2), 5));
    add(Ball(screenToWorld(camera.viewport.effectiveSize / 2), 5));
  }

  @override
  bool onDragUpdate(int pointerId, DragUpdateInfo details) {
    final mouseJointDef = MouseJointDef()
      ..maxForce = 3000 * grabbedBody.body.mass * 10 //Not neccerly needed
      ..dampingRatio = 0.1
      ..frequencyHz = 5
      ..target.setFrom(grabbedBody.body.position)
      ..collideConnected = false //Maybe set to true
      ..bodyA = groundBody
      ..bodyB = grabbedBody.body;

    mouseJoint ??= world.createJoint(mouseJointDef) as MouseJoint;

    mouseJoint?.setTarget(details.eventPosition.game);
    return false;
  }

  @override
  bool onDragEnd(int pointerId, DragEndInfo details) {
    if (mouseJoint == null) {
      return true;
    }
    world.destroyJoint(mouseJoint!);
    mouseJoint = null;
    return false;
  }
}

class Ball extends BodyComponent with Tappable {
  final Vector2 position;
  final double radius;
  final BodyType bodyType;
  Ball(this.position, this.radius, {this.bodyType = BodyType.dynamic});

  @override
  Body createBody() {
    final shape = CircleShape();
    shape.radius = radius;
    final fixtureDef = FixtureDef(shape)
      ..restitution = 0.8
      ..density = 1.0
      ..friction = 0.4;

    final bodyDef = BodyDef()
      // To be able to determine object in collision
      ..userData = this
      ..angularDamping = 0.8
      ..position = position
      ..type = bodyType;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  bool onTapDown(_) {
    MyGame.grabbedBody = this;
    return false;
  }
}
