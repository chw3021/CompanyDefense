package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class Stage {
    protected ShapeRenderer shapeRenderer;
    protected Array<Enemy> enemies;
    protected Array<Tower> towers;
    protected Array<Wave> waves;
    private int currentWaveIndex;
    protected Wave currentWave;
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    
    
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected int gridSize = 40;
    protected Array<Obstacle> pathVisuals;
    private TextButton spawnButton;
    private TextButton.TextButtonStyle buttonStyle;
    private Skin skin;
    
    protected AStarPathfinding aStar;  // AStar 경로 탐색
    protected int life = 10;  // 초기 Life 설정

    // 맵의 크기 (gridWidth, gridHeight)
    protected int mapWidth = 20;  // 예시: 맵의 가로 크기
    protected int mapHeight = 20; // 예시: 맵의 세로 크기
    
    // 소환할 수 있는 타워 리스트
    protected Array<Tower> availableTowers;
 // 소환 가능한 타워의 영역을 확인
    protected boolean canSpawnTowerAt(float x, float y) {
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
    public void setupWave(Wave wave) {
        waves.add(wave);
    }

    // 웨이브 업데이트 메서드
    public void updateWave(float delta) {
        timeSinceLastWave += delta;

        if (timeSinceLastWave >= waveTimeInterval) {
            spawnNextWave(delta);
            timeSinceLastWave = 0;  // 시간 초기화
        }
        if (currentWaveIndex < waves.size) {
            Wave currentWave = waves.get(currentWaveIndex);
            currentWave.execute(delta, enemies);  // 적 소환
            if (currentWave.isComplete()) {
                currentWaveIndex++;  // 웨이브 완료 시 다음 웨이브로 이동
            }
        }
        checkWaveCompletion();
    }

    // 다음 웨이브 적들 추가
    private void spawnNextWave(float delta) {
        if (currentWaveIndex < waves.size) {
            Wave currentWave = waves.get(currentWaveIndex);
            currentWave.spawnEnemies(enemies);  // 현재 웨이브의 적을 소환
        }
    }

    // 웨이브 완료 체크
    public void checkWaveCompletion() {
        if (enemies.isEmpty() && currentWaveIndex < waves.size) {
            if (waves.get(currentWaveIndex).isComplete()) {
                win();  // 승리 처리
            }
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
    public Stage() {
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("uiskin.json"));
        towers = new Array<>();
        
        enemies = new Array<>();
        waves = new Array<>();
        currentWaveIndex = 0;
    }

    // 스테이지 초기화
    public abstract void initialize();

    public void render(SpriteBatch batch) {
        // 배경이나 맵 등의 요소를 먼저 렌더링

        batch.begin();

        // Spawn 버튼 스타일 설정
        buttonStyle = new TextButton.TextButtonStyle();
        buttonStyle.font = new BitmapFont();  // 기본 폰트 사용
        buttonStyle.up = skin.getDrawable("default-rect");  // 버튼 배경
        buttonStyle.down = skin.getDrawable("default-rect");  // 버튼 클릭 시 배경
        buttonStyle.fontColor = Color.WHITE;  // 텍스트 색상 설정

        // Spawn 버튼 생성 및 설정
        if (spawnButton == null) {  // 버튼을 한 번만 생성하도록 조건 추가
            spawnButton = new TextButton("Spawn", buttonStyle);
            spawnButton.setPosition(Gdx.graphics.getWidth() - 220, 20);  // 버튼 위치
            spawnButton.setSize(200, 50);  // 버튼 크기
        }

        // 버튼을 화면에 그리기
        spawnButton.draw(batch, 1);

        // 버튼 클릭 이벤트 처리
        if (Gdx.input.isTouched()) {
            float mouseX = Gdx.input.getX();
            float mouseY = Gdx.graphics.getHeight() - Gdx.input.getY();  // Y 좌표 반전
            if (mouseX >= spawnButton.getX() && mouseX <= spawnButton.getX() + spawnButton.getWidth() &&
                mouseY >= spawnButton.getY() && mouseY <= spawnButton.getY() + spawnButton.getHeight()) {
                spawnTower();  // 타워 소환
            }
        }

        batch.end();

        batch.begin();
        for (Enemy enemy : enemies) {
            enemy.render(batch);  // 적 그리기
        }
        batch.end();
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

