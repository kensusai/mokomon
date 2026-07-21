import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mokomon/data/foods.dart';
import 'package:mokomon/data/save_store.dart';
import 'package:mokomon/data/species.dart';
import 'package:mokomon/logic/game_controller.dart';
import 'package:mokomon/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameController fresh([GameState? state, Random? rng]) =>
      GameController(state ?? GameState(), SaveStore(), rng: rng);

  group('tapCreature (docs/game-design.md §3, §9)', () {
    test('egg stage: cracks then hatches', () {
      final c = fresh();
      expect(c.tapCreature(lowerBody: false), CreatureTapOutcome.crack);
      expect(c.tapCreature(lowerBody: true), CreatureTapOutcome.crack);
      expect(c.tapCreature(lowerBody: false), CreatureTapOutcome.hatched);
    });

    test('lower-body tap always puffs (happy +2, no xp)', () {
      final c = fresh(GameState()..stage = 1, FixedRandom(0.99));
      expect(c.tapCreature(lowerBody: true), CreatureTapOutcome.puffed);
      expect(c.state.happy, 82);
      expect(c.state.xp, 0);
    });

    test('normal tap pets unless the 6% roll fires', () {
      final pet = fresh(GameState()..stage = 1, FixedRandom(0.5));
      expect(pet.tapCreature(lowerBody: false), CreatureTapOutcome.petted);
      expect(pet.state.xp, 1);

      final puff = fresh(GameState()..stage = 1, FixedRandom(0.05));
      expect(puff.tapCreature(lowerBody: false), CreatureTapOutcome.puffed);
      expect(puff.state.xp, 0);
    });
  });

  group('egg tapping (docs/game-design.md §4)', () {
    test('first two taps crack, third hatches with xp 5', () {
      final c = fresh();
      expect(c.tapEgg(), EggTapOutcome.crack);
      expect(c.state.eggTaps, 1);
      expect(c.tapEgg(), EggTapOutcome.crack);
      expect(c.tapEgg(), EggTapOutcome.hatched);
      expect(c.state.stage, 1);
      expect(c.state.xp, 5);
    });
  });

  group('feed (docs/game-design.md §3)', () {
    test('applies cost and gains with clamping', () {
      final c = fresh(
        GameState()
          ..stage = 1
          ..coins = 10
          ..hunger = 50
          ..happy = 90,
      );
      final cake = foods.firstWhere((f) => f.key == 'cake');
      expect(c.feed(cake), FeedOutcome.fed);
      expect(c.state.coins, 0);
      expect(c.state.hunger, 95); // 50 + 45
      expect(c.state.happy, 100); // 90 + 14 clamped
      expect(c.state.xp, 9);
    });

    test('fails without enough coins and changes nothing', () {
      final c = fresh(
        GameState()
          ..stage = 1
          ..coins = 2,
      );
      expect(c.feed(foods.first), FeedOutcome.notEnoughCoins);
      expect(c.state.coins, 2);
      expect(c.state.hunger, 80);
    });

    test('isFull blocks feeding UI at hunger >= 98', () {
      expect(fresh(GameState()..hunger = 98).isFull, isTrue);
      expect(fresh(GameState()..hunger = 97.9).isFull, isFalse);
    });
  });

  group('decayTick (docs/game-design.md §3)', () {
    test('drains hunger 0.6 / happy 0.35 per tick, floored at 0', () {
      final s = GameState()
        ..stage = 1
        ..hunger = 1
        ..happy = 0.5;
      final c = fresh(s);
      c.decayTick();
      expect(s.hunger, closeTo(0.4, 1e-9));
      expect(s.happy, closeTo(0.15, 1e-9));
      c.decayTick();
      c.decayTick();
      expect(s.hunger, 0);
      expect(s.happy, 0);
    });

    test('egg stage does not decay', () {
      final c = fresh();
      c.decayTick();
      expect(c.state.hunger, 80);
      expect(c.state.happy, 80);
    });
  });

  group('evolution application', () {
    test('applyEvolution to king registers collection', () {
      final s = GameState()
        ..stage = 2
        ..xp = 80
        ..species = 1;
      final c = fresh(s);
      expect(s.evolveCheck(), 3);
      c.applyEvolution(3);
      expect(s.stage, 3);
      expect(s.collection[1], isTrue);
    });

    test('applyEvolution to stage 2 does not register collection', () {
      final c = fresh(
        GameState()
          ..stage = 1
          ..xp = 30,
      );
      c.applyEvolution(2);
      expect(c.state.stage, 2);
      expect(c.state.collection[0], isFalse);
    });
  });

  group('newEgg (docs/game-design.md §4)', () {
    test('resets state for the drawn species', () {
      final s = GameState()
        ..stage = 3
        ..xp = 99
        ..coins = 50
        ..hunger = 12
        ..happy = 15
        ..eggTaps = 3
        ..species = 0
        ..color = 0xFF123456;
      s.collection[0] = true;
      final c = fresh(s, Random(1));
      final next = c.newEgg();
      expect(next, isNot(0)); // unowned normals only
      expect(s.species, next);
      expect(s.stage, 0);
      expect(s.eggTaps, 0);
      expect(s.xp, 0);
      expect(s.hunger, 80);
      expect(s.happy, 80);
      expect(s.coins, 50); // coins are kept
      expect(s.color, speciesList[next].color.toARGB32());
    });
  });

  group('body color state', () {
    test('defaults to species 0 color and survives json roundtrip', () {
      final s = GameState();
      expect(s.color, speciesList[0].color.toARGB32());
      s.color = 0xFFFFD23E;
      final restored = GameState()..loadJson(s.toJson());
      expect(restored.color, 0xFFFFD23E);
    });

    test('loadCode resets color to species default', () {
      final s = GameState()
        ..species = 2
        ..color = 0xFF111111;
      final restored = GameState();
      expect(restored.loadCode(s.makeCode()), isTrue);
      expect(restored.color, speciesList[2].color.toARGB32());
    });
  });

  group('display name', () {
    test('includes stage emoji like the prototype name pill', () {
      expect(GameState().displayName, '🥚 たまご');
      expect((GameState()..stage = 1).displayName, '🐣 もこ');
      expect(
        (GameState()
              ..species = 3
              ..stage = 0)
            .displayName,
        '🥚 きんのたまご',
      );
      expect(
        (GameState()
              ..species = 5
              ..stage = 3)
            .displayName,
        '👑 キングぶー',
      );
    });
  });
}
