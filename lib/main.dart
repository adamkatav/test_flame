import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/widgets.dart';
import 'package:test_flame/boundaries.dart';

Vector2 vec2Median(List<Vector2> vecs) {
  var sum = Vector2(0, 0);
  for (final v in vecs) {
    sum += v;
  }
  return sum / vecs.length.toDouble();
}

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
    final center = screenToWorld(camera.viewport.effectiveSize / 2);
    var ball = Ball(center, 1, bodyType: BodyType.dynamic);
    add(ball);
    final poly = Polygon([
      center + Vector2(0, 0),
      center + Vector2(0, 5),
      center + Vector2(5, 0),
      //center + Vector2(5, 5)
    ]);
    add(poly);
    grabbedBody = poly;
  }

  @override
  bool onDragUpdate(int pointerId, DragUpdateInfo details) {
    final mouseJointDef = MouseJointDef()
      ..maxForce = 3000 * grabbedBody.body.mass * 10 //Not neccerly needed
      ..dampingRatio = 1
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

abstract class TappableBodyComponent extends BodyComponent with Tappable {
  final Vector2 position;
  final BodyType bodyType;
  TappableBodyComponent(this.position, {this.bodyType = BodyType.dynamic});

  @override
  bool onTapDown(_) {
    MyGame.grabbedBody = this;
    return false;
  }

  Body tappableBCreateBody(Shape shape) {
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
}

class Ball extends TappableBodyComponent {
  final double radius;

  Ball(Vector2 position, this.radius, {BodyType bodyType = BodyType.dynamic})
      : super(position, bodyType: bodyType);

  @override
  Body createBody() {
    final shape = CircleShape();
    shape.radius = radius;
    return tappableBCreateBody(shape);
  }
}

class Polygon extends TappableBodyComponent {
  final List<Vector2> vertecies;

  Polygon(this.vertecies) : super(vec2Median(vertecies));

  @override
  Body createBody() {
    final shape = PolygonShape()..set(vertecies);
    return tappableBCreateBody(shape);
  }
}
