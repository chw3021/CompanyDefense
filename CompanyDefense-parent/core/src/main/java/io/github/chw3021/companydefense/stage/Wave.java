package io.github.chw3021.companydefense.stage;

import java.util.function.Consumer;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
public class Wave {
    private Array<Enemy> waveEnemies;
    private boolean complete;
    private float spawnDelay;
    private float timeSinceLastSpawn;
    private boolean started;

    public Wave(Array<Enemy> waveEnemies, float spawnDelay) {
        this.waveEnemies = waveEnemies;
        this.spawnDelay = spawnDelay;
        this.timeSinceLastSpawn = 0;
        this.complete = false;
        this.started = false;
    }

    public Wave(float spawnDelay) {
        this.waveEnemies = new Array<>();
        this.spawnDelay = spawnDelay;
        this.timeSinceLastSpawn = 0;
        this.complete = false;
        this.started = false;
    }
    public boolean isComplete() {
        return complete;
    }
    
    public boolean removeEnemy(Enemy enemy) {
    	return waveEnemies.removeValue(enemy, true);
    }
    
    public void addEnemy(Enemy enemy) {
    	waveEnemies.add(enemy);
    }

    public void execute(float delta, Array<Enemy> activeEnemies, StageParent stage) {
        if (!started) {
            started = true;
            timeSinceLastSpawn = 0;
        }

        if (!waveEnemies.isEmpty()) {
            timeSinceLastSpawn += delta;

            if (timeSinceLastSpawn >= spawnDelay) {
                Enemy enemyToSpawn = waveEnemies.removeIndex(0);
                activeEnemies.add(enemyToSpawn);
                enemyToSpawn.update();
                timeSinceLastSpawn = 0.0f;
            }
        } else if (activeEnemies.isEmpty()) {
            complete = true;
        }
    }
}

