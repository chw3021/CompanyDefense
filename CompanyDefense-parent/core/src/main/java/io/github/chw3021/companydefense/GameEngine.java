package io.github.chw3021.companydefense;

import com.badlogic.ashley.core.Engine;

import io.github.chw3021.companydefense.pathfinding.PathfindingSystem;
import io.github.chw3021.companydefense.system.DamageSystem;
import io.github.chw3021.companydefense.system.MovementSystem;

public class GameEngine {
    private Engine engine;

    public GameEngine() {
        engine = new Engine();

        // 시스템 추가
        engine.addSystem(new MovementSystem());
        engine.addSystem(new DamageSystem());
        engine.addSystem(new PathfindingSystem(20, 20, 32)); // 그리드 크기 예제
    }

    public Engine getEngine() {
        return engine;
    }
}
