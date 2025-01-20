package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class Stage {
    protected SpriteBatch batch;
    protected Texture background;
    protected ShapeRenderer shapeRenderer;
    protected Array<Enemy> enemies;
    protected Array<Tower> towers;
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected int gridSize = 40;
    
    protected AStarPathfinding aStar;  // AStar 경로 탐색
    protected int life = 10;  // 초기 Life 설정
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    protected Wave currentWave;  // 현재 웨이브 관리

    // 맵의 크기 (gridWidth, gridHeight)
    protected int mapWidth = 20;  // 예시: 맵의 가로 크기
    protected int mapHeight = 20; // 예시: 맵의 세로 크기
    
    // 소환할 수 있는 타워 리스트
    protected Array<Tower> availableTowers;
 // 소환 가능한 타워의 영역을 확인
    private boolean canSpawnTowerAt(float x, float y) {
        // 맵 밖일 때 소환 불가
        if (x < 0 || x >= mapWidth * gridSize || y < 0 || y >= mapHeight * gridSize) {
            return false;
        }

        // 이미 타워가 있는지 확인
        for (Tower tower : towers) {
            if (tower.getPosition().x == x && tower.getPosition().y == y) {
                return false;
            }
        }

        // 장애물이 있는지 확인
        boolean obstacleFound = false;
        for (Obstacle obstacle : obstacles) {
            if (obstacle.getX() == x && obstacle.getY() == y) {
                obstacleFound = true;  // 장애물이 있는 곳
                break;
            }
        }

        return obstacleFound; // 장애물이 있어야만 소환 가능
    }

    // 타워 소환 메서드
    public void spawnTower() {
        // 랜덤하게 타워를 소환
        if (availableTowers.size == 0) return; // 소환할 수 있는 타워가 없으면 종료

        // 랜덤으로 타워 선택
        Tower towerToSpawn = availableTowers.random();

        // 랜덤 위치 찾기 (소환 가능한 위치)
        float spawnX, spawnY;
        boolean foundSpot = false;

        for (int i = 0; i < 100; i++) { // 최대 100번 시도
            spawnX = (float) Math.random() * mapWidth * gridSize;
            spawnY = (float) Math.random() * mapHeight * gridSize;

            if (canSpawnTowerAt(spawnX, spawnY)) {
                towers.add(towerToSpawn);
                towerToSpawn.setPosition(new Vector2(spawnX, spawnY)); // 타워 위치 설정
                foundSpot = true;
                break;
            }
        }

        // 만약 소환할 수 있는 자리가 없다면 실패 메시지 출력
        if (!foundSpot) {
            System.out.println("Cannot spawn tower: No valid spot available!");
        }
    }

    // Wave 관리 및 처리
    public void setupWave(Array<Enemy> waveEnemies) {
        currentWave = new Wave(waveEnemies);
    }

    // 웨이브 업데이트 메서드
    public void updateWave(float delta) {
        timeSinceLastWave += delta;

        if (timeSinceLastWave >= waveTimeInterval) {
            spawnNextWave(delta);
            timeSinceLastWave = 0;  // 시간 초기화
        }
    }

    // 다음 웨이브 적들 추가
    private void spawnNextWave(float delta) {
        if (currentWave != null) {
            currentWave.execute(delta, enemies); 
        }
    }

    // 웨이브 완료 체크
    public void checkWaveCompletion() {
        if (enemies.isEmpty() && currentWave != null && currentWave.isComplete()) {
            win();
        }
    }


    // 게임 종료 처리
    private void gameOver() {
        System.out.println("Game Over!");
        // 게임 종료 로직
    }

    // 승리 처리
    private void win() {
        System.out.println("You Win!");
        // 게임 승리 로직
    }

    // 스테이지 초기화
    public abstract void initialize();
    
    // 버튼을 렌더링하고 클릭 이벤트를 처리하는 부분
    public void render(float delta) {
        batch.begin();
        batch.draw(background, 0, 0);

        // Spawn 버튼 그리기 (버튼 크기와 위치 설정)
        float buttonWidth = 200;
        float buttonHeight = 50;
        float buttonX = Gdx.graphics.getWidth() - buttonWidth - 20;
        float buttonY = 20;

        // Spawn 버튼 사각형 그리기
        shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
        shapeRenderer.setColor(Color.GREEN);
        shapeRenderer.rect(buttonX, buttonY, buttonWidth, buttonHeight);
        shapeRenderer.end();

        // 버튼 텍스트 그리기
        BitmapFont font = new BitmapFont(); // 기본 폰트 사용
        font.setColor(Color.WHITE);
        font.draw(batch, "Spawn", buttonX + buttonWidth / 2 - font.getRegion().getRegionWidth() / 2, buttonY + buttonHeight / 2 + font.getRegion().getRegionHeight() / 2);

        batch.end();

        // Spawn 버튼 클릭 이벤트 처리
        if (Gdx.input.isTouched()) {
            float mouseX = Gdx.input.getX();
            float mouseY = Gdx.input.getY();
            if (mouseX >= buttonX && mouseX <= buttonX + buttonWidth &&
                mouseY >= buttonY && mouseY <= buttonY + buttonHeight) {
                spawnTower();  // 타워 소환
            }
        }
    }


    // 장애물 추가 메서드
    public void addObstacle(Obstacle obstacle) {
        if (obstacles == null) {
            obstacles = new Array<>();
        }
        obstacles.add(obstacle);
    }

    // AStar 초기화 및 장애물 설정
    public void setupAStar() {
        aStar = new AStarPathfinding(mapWidth, mapHeight, gridSize);

        Obstacle[][] obstacleMap = new Obstacle[mapWidth][mapHeight];
        for (Obstacle obstacle : obstacles) {
            int x = (int) (obstacle.getX() / gridSize);  
            int y = (int) (obstacle.getY() / gridSize);  
            obstacleMap[x][y] = obstacle;
        }
        aStar.setObstacles(obstacleMap);
    }

    // 적이 목표 지점에 도달하거나 생명 0일 때 처리
    public void handleEnemyExit(Enemy enemy) {
        enemies.removeValue(enemy, true);  
        life--;  
        if (life <= 0) {
            gameOver();
        }
    }

    // 게임 종료 처리
    public void dispose() {
        batch.dispose();
        background.dispose();
        shapeRenderer.dispose();
        for (Tower tower : towers) {
            tower.dispose();
        }
        if (obstacles != null) {
            for (Obstacle obstacle : obstacles) {
                obstacle.dispose();
            }
        }
    }
}

