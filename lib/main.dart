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
    boundaries.forEach(await add);

    groundBody = world.createBody(BodyDef());

    final center = screenToWorld(camera.viewport.effectiveSize / 2);
    final bottom_right = screenToWorld(camera.viewport.effectiveSize);
    final upper_left = Vector2(0, 0);
    final bottom_left = Vector2(upper_left.x, bottom_right.y);

    /*var test_ball = Ball(Vector2(upper_left.x, bottom_right.y), 2.5,
        bodyType: BodyType.static);
    await add(test_ball);*/

    var wheel1 = Ball(center + Vector2(-10, -5) + Vector2(2.5, 0), 2.5,
        bodyType: BodyType.dynamic);
    await add(wheel1);
    var wheel2 = Ball(center + Vector2(10, -5) + Vector2(-2.5, 0), 2.5,
        bodyType: BodyType.dynamic);
    await add(wheel2);
    var verteces = [
      Vector2(-10, -5),
      Vector2(-10, 5),
      Vector2(10, -5),
      Vector2(10, 5)
    ];
    final cartRect = Polygon(center, verteces, bodyType: BodyType.dynamic);
    await add(cartRect);
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel1.body, wheel1.position));
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel2.body, wheel2.position));
    final rect =
        Polygon(center + Vector2(50, 50), verteces, bodyType: BodyType.dynamic);
    await add(rect);
    final trig = Polygon(upper_left, [upper_left, bottom_left, bottom_right],
        bodyType: BodyType.static);
    await add(trig);
    grabbedBody = cartRect;
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

class Polygon extends TappableBodyComponent {
  final List<Vector2> vertecies;

  Polygon(Vector2 offset, this.vertecies,
      {BodyType bodyType = BodyType.dynamic})
      : super(/*vec2Median(vertecies) + */ offset, bodyType: bodyType);

  @override
  Body createBody() {
    final shape = PolygonShape()..set(vertecies);
    return tappableBCreateBody(shape);
  }
}
/*
class Cart extends TappableBodyComponent {
  final List<Vector2> vertecies;
  final Vector2 offset;
  final double radius;
  Cart(this.offset, this.vertecies, this.radius,
      {BodyType bodyType = BodyType.dynamic})
      : super(vec2Median(vertecies) + offset, bodyType: bodyType);

  @override
  Body createBody() {
    Polygon rect = Polygon(offset, vertecies);
    Ball wheel1 = Ball(
        offset - vertecies[1], radius); // offset - vertecies[1] is B vertex
    Ball wheel2 = Ball(
        offset - vertecies[2], radius); // offset - vertecies[1] is C vertex
    Body rectBody = rect.createBody();
    Body wheel1Body = wheel1.createBody();
    Body wheel2Body = wheel2.createBody();
    rect.add(wheel1);
    rect.add(wheel2);

    world.createJoint(
        RevoluteJointDef()..initialize(rectBody, wheel1Body, wheel1.position));
    world.createJoint(
        RevoluteJointDef()..initialize(rectBody, wheel2Body, wheel2.position));
        
    return rectBody;
  }
}
*/