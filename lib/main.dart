import 'dart:math';

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
    super.onLoad();
    final boundaries = createBoundaries(this); //Adding boundries
    boundaries.forEach(add);

    groundBody = world.createBody(BodyDef());

    final center = screenToWorld(camera.viewport.effectiveSize / 2);
    final bottom_right = screenToWorld(camera.viewport.effectiveSize);
    final upper_left = Vector2(0, 0);
    final bottom_left = Vector2(upper_left.x, bottom_right.y);
    // 271 is a convinient number to have nice constents while developing on my 14" laptop
    double scale = bottom_right.length / 271;

    //To find locations on the screen
    /*var test_ball = Ball(Vector2(upper_left.x, bottom_right.y), 2.5,
        bodyType: BodyType.static);
    await add(test_ball);*/

    //Just a fun ball
    var ball1 = Ball(center + Vector2(5, 5) * scale, 5 * scale,
        bodyType: BodyType.static);
    await add(ball1);

    var ball2 = Ball(center + Vector2(30, 30) * scale, 5 * scale,
        bodyType: BodyType.dynamic);
    await add(ball2);

    var cart_verteces = [
      Vector2(-10, -5) * scale,
      Vector2(-10, 5) * scale,
      Vector2(10, -5) * scale,
      Vector2(10, 5) * scale
    ];
    var verteces = [
      Vector2(-20, -5) * scale,
      Vector2(-20, 5) * scale,
      Vector2(0, -5) * scale,
      Vector2(0, 5) * scale
    ];
/*
    // Cart example start
    var wheel1 = Ball(
        center + (Vector2(-10, -5) + Vector2(2.5, 0)) * scale, 2.5 * scale,
        bodyType: BodyType.dynamic);
    await add(wheel1);
    var wheel2 = Ball(
        center + (Vector2(10, -5) + Vector2(-2.5, 0)) * scale, 2.5 * scale,
        bodyType: BodyType.dynamic);
    await add(wheel2);

    final cartRect = Polygon(center, verteces, bodyType: BodyType.dynamic);
    await add(cartRect);
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel1.body, wheel1.position));
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel2.body, wheel2.position));
    // Cart example end
*/
    //Rectangle with friction
    /*final rect = Polygon(center + Vector2(50, 50) * scale, verteces,
        bodyType: BodyType.dynamic);
    await add(rect);
*/
    //To show difference between cart and rectangle
    final trig = Polygon(upper_left, [upper_left, bottom_left, bottom_right],
        bodyType: BodyType.static);
    await add(trig);
    Polygon cart = await makeCart(center, cart_verteces, 2.5 * scale);

    //DistantJoint example
    world.createJoint(DistanceJointDef()
      ..initialize(ball1.body, ball2.body, ball1.position, ball2.position)
      ..dampingRatio = 0.0
      ..frequencyHz =
          (1 / (2 * pi) * sqrt(20 / (ball2.body.mass + ball1.body.mass))));
  }

  //Expects scaled values
  Future<Polygon> makeCart(
      Vector2 offset, List<Vector2> verteces, double wheel_radius,
      {BodyType bodyType = BodyType.dynamic}) async {
    final center = screenToWorld(camera.viewport.effectiveSize / 2);
    final rect_bottom_unit_vec = (verteces[2] - verteces[0]).normalized();
    var wheel1 = Ball(
        center + (verteces[0] + rect_bottom_unit_vec * wheel_radius),
        wheel_radius,
        bodyType: bodyType);
    await add(wheel1);
    var wheel2 = Ball(
        center + (verteces[2] + rect_bottom_unit_vec * -wheel_radius),
        wheel_radius,
        bodyType: bodyType);
    await add(wheel2);
    final cartRect = Polygon(center, verteces, bodyType: bodyType);
    await add(cartRect);

    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel1.body, wheel1.position));
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel2.body, wheel2.position));
    return cartRect;
  }

  //For mouseJoint
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

  //For mouseJoint
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

/**
 * Abstract class that encapsulate all rigid bodies properties
 */
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
      ..friction = 1;

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

/**
 * Polygon class, remember to place veteces around offset so MouseJoint will work correctly
 */
class Polygon extends TappableBodyComponent {
  final List<Vector2> vertecies;

  Polygon(Vector2 offset, this.vertecies,
      {BodyType bodyType = BodyType.dynamic})
      : super(offset, bodyType: bodyType);

  @override
  Body createBody() {
    final shape = PolygonShape()..set(vertecies);
    return tappableBCreateBody(shape);
  }
}
