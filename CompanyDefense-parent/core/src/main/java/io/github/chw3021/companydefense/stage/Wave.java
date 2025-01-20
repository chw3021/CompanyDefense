package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
public class Wave {
    private Array<Enemy> waveEnemies;
    private boolean complete;
    private float spawnDelay;  // 적을 소환하는 간격 (초 단위)
    private float timeSinceLastSpawn;  // 마지막 소환 후 경과 시간

    public Wave(Array<Enemy> waveEnemies, float spawnDelay) {
        this.waveEnemies = waveEnemies;
        this.spawnDelay = spawnDelay;
        this.timeSinceLastSpawn = 0;
        this.complete = false;
    }

    // 웨이브에 포함된 적들이 모두 나갔으면 true 반환
    public boolean isComplete() {
        return waveEnemies.isEmpty();  // 웨이브에 적이 없으면 완료
    }

    // 웨이브에 있는 적들을 소환
    public void spawnEnemies(Array<Enemy> allEnemies) {
        for (Enemy enemy : waveEnemies) {
            allEnemies.add(enemy);  // 전체 적 리스트에 추가
        }
        waveEnemies.clear();  // 웨이브 리스트 비우기
    }

    // 웨이브 실행 메서드
    public void execute(float delta, Array<Enemy> allEnemies) {
        // 적들이 아직 남아있고 소환할 수 있는 적이 있으면 하나씩 소환
        if (!waveEnemies.isEmpty()) {
            timeSinceLastSpawn += delta;  // 경과 시간 업데이트

            if (timeSinceLastSpawn >= spawnDelay) {
                // 웨이브에서 하나의 적을 소환
                Enemy enemyToSpawn = waveEnemies.removeIndex(0);  // 첫 번째 적 꺼내기
                allEnemies.add(enemyToSpawn);  // 전체 적 리스트에 추가
                timeSinceLastSpawn = 0.0f;  // 소환 간격 초기화
            }
        }
    }
}
