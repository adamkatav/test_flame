import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:test_flame/boundaries.dart';

Vector2 vec2Median(List<Vector2> vecs) {
  var sum = Vector2(0, 0);
  for (final v in vecs) {
    sum += v;
  }
  return sum / vecs.length.toDouble();
}

Vector2 strToVec2(String vec) {
  return Vector2(
      double.parse(vec.split(', ')[0]), double.parse(vec.split(', ')[1]));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
  ]).then((value) => runApp(GameWidget(game: MyGame())));
}

class MyGame extends Forge2DGame with MultiTouchDragDetector, HasTappables {
  MouseJoint? mouseJoint;
  static late BodyComponent grabbedBody;
  late Body groundBody;
  MyGame() : super(gravity: Vector2(0, -10.0));
  late double scale;
  //Game onLoad
  @override
  Future<void> onLoad() async {
    //final center = screenToWorld(camera.viewport.effectiveSize / 2);
    final bottom_right = screenToWorld(camera.viewport.effectiveSize);
    //final upper_left = Vector2(0, 0);
    //final bottom_left = Vector2(upper_left.x, bottom_right.y);
    scale = bottom_right.length / 271;
    var dummy_for_mouse_joint =
        Ball(Vector2(-5, 5) * scale, 0.1 * scale, bodyType: BodyType.static);
    await add(dummy_for_mouse_joint);
    grabbedBody = dummy_for_mouse_joint;
    final data =
        await json.decode(await rootBundle.loadString('assets/sample.json'));
    //Adding tringles
    var trig_list = <Polygon>[];
    for (var trig in data["Triangles"]) {
      var ver = [
        strToVec2(trig["A"]) * scale,
        strToVec2(trig["B"]) * scale,
        strToVec2(trig["C"]) * scale
      ];
      var center_of_mass = vec2Median(ver);
      //Polygon is created around center of mass so we have to shift the vertecies back in order to create them in relation to upper_left
      ver = [
        strToVec2(trig["A"]) * scale - center_of_mass,
        strToVec2(trig["B"]) * scale - center_of_mass,
        strToVec2(trig["C"]) * scale - center_of_mass
      ];
      Polygon pol = Polygon(center_of_mass, ver, bodyType: BodyType.dynamic);
      trig_list.add(pol);
      await add(pol);
    }

    var block_list = <Polygon>[];
    for (var block in data["Blocks"]) {
      var ver = [
        strToVec2(block["A"]) * scale,
        strToVec2(block["B"]) * scale,
        strToVec2(block["C"]) * scale,
        strToVec2(block["D"]) * scale
      ];
      var center_of_mass = vec2Median(ver);
      //Polygon is created around center of mass so we have to shift the vertecies back in order to create them in relation to upper_left
      ver = [
        strToVec2(block["A"]) * scale - center_of_mass,
        strToVec2(block["B"]) * scale - center_of_mass,
        strToVec2(block["C"]) * scale - center_of_mass,
        strToVec2(block["D"]) * scale - center_of_mass
      ];
      Polygon pol = Polygon(center_of_mass, ver,
          bodyType: block["IsStatic"] ? BodyType.static : BodyType.dynamic);
      block_list.add(pol);
      await add(pol);
    }

    var wall_list = <Polygon>[];
    for (var wall in data["Walls"]) {
      var start = strToVec2(wall["A"]) * scale;
      var end = strToVec2(wall["B"]) * scale;
      Vector2 O =
          Vector2(start.y - end.y, end.x - start.x) / ((end - start).length);
      var ver = [start + O, end + O, start - O, end - O];
      var center_of_mass = vec2Median(ver);
      //Polygon is created around center of mass so we have to shift the vertecies back in order to create them in relation to upper_left
      ver = [
        start + O - center_of_mass,
        end + O - center_of_mass,
        start - O - center_of_mass,
        end - O - center_of_mass
      ];
      Polygon pol = Polygon(center_of_mass, ver, bodyType: BodyType.static);
      wall_list.add(pol);
      await add(pol);
    }

    var cart_list = <Polygon>[];
    for (var cart in data["Carts"]) {
      var ver = [
        strToVec2(cart["A"]) * scale,
        strToVec2(cart["B"]) * scale,
        strToVec2(cart["C"]) * scale,
        strToVec2(cart["D"]) * scale
      ];
      var center_of_mass = vec2Median(ver);
      //Polygon is created around center of mass so we have to shift the vertecies back in order to create them in relation to upper_left
      ver = [
        strToVec2(cart["A"]) * scale - center_of_mass,
        strToVec2(cart["B"]) * scale - center_of_mass,
        strToVec2(cart["C"]) * scale - center_of_mass,
        strToVec2(cart["D"]) * scale - center_of_mass
      ];
      Polygon pol = await makeCart(
          center_of_mass,
          ver,
          (cart["radius"] * scale),
          strToVec2(cart["wheel1"]) * scale,
          strToVec2(cart["wheel2"]) * scale);
      cart_list.add(pol);
      await add(pol);
    }

    var ball_list = <Ball>[];
    for (var ball in data["Balls"]) {
      Ball b = Ball(strToVec2(ball["Center"]) * scale, ball["Radius"] * scale,
          bodyType: ball["IsStatic"] ? BodyType.static : BodyType.dynamic);
      ball_list.add(b);
      await add(b);
    }

    for (var spring in data["Springs"]) {
      var connectionA;
      switch (spring["connectionA"]) {
        case "Carts":
          connectionA = cart_list;
          break;
        case "Balls":
          connectionA = ball_list;
          break;
        case "Walls":
          connectionA = wall_list;
          break;
        case "Blocks":
          connectionA = block_list;
          break;
        case "Triangles":
          connectionA = trig_list;
          break;
        default:
      }
      var connectionB;
      switch (spring["connectionB"]) {
        case "Carts":
          connectionB = cart_list;
          break;
        case "Balls":
          connectionB = ball_list;
          break;
        case "Walls":
          connectionB = wall_list;
          break;
        case "Blocks":
          connectionB = block_list;
          break;
        case "Triangles":
          connectionB = trig_list;
          break;
        default:
      }
      var body1 = connectionA[spring["indexA"]];
      var body2 = connectionB[spring["indexB"]];
      world.createJoint(DistanceJointDef()
        ..initialize(
            body1.body, body2.body, body1.center_of_mass, body2.center_of_mass)
        ..dampingRatio = 0.0
        ..frequencyHz =
            (1 / (2 * pi) * sqrt(50 / (body2.body.mass + body1.body.mass))));
    }

    super.onLoad();
    final boundaries = createBoundaries(this); //Adding boundries
    boundaries.forEach(add);

    groundBody = world.createBody(BodyDef());
    // 271 is a convinient number to have nice constents while developing on my 14" laptop
  }

  //Expects scaled values
  Future<Polygon> makeCart(Vector2 center_of_mass, List<Vector2> verteces,
      double wheel_radius, Vector2 wheel1_pos, Vector2 wheel2_pos,
      {BodyType bodyType = BodyType.dynamic}) async {
    var wheel1 = Ball(wheel1_pos, wheel_radius, bodyType: bodyType);
    await add(wheel1);
    var wheel2 = Ball(wheel2_pos, wheel_radius, bodyType: bodyType);
    await add(wheel2);
    final cartRect = Polygon(center_of_mass, verteces, bodyType: bodyType);
    await add(cartRect);

    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel1.body, wheel1.center_of_mass));
    world.createJoint(RevoluteJointDef()
      ..initialize(cartRect.body, wheel2.body, wheel2.center_of_mass));
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
  final Vector2 center_of_mass;
  final BodyType bodyType;
  TappableBodyComponent(this.center_of_mass,
      {this.bodyType = BodyType.dynamic});

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
      ..position = center_of_mass
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

  Polygon(Vector2 center_of_mass, this.vertecies,
      {BodyType bodyType = BodyType.dynamic})
      : super(center_of_mass, bodyType: bodyType);

  @override
  Body createBody() {
    final shape = PolygonShape()..set(vertecies);
    return tappableBCreateBody(shape);
  }
}
