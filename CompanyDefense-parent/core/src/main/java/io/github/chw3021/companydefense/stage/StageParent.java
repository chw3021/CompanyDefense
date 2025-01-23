package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class StageParent extends Stage{
	protected float[][] map; // 맵 데이터 (0: 빈 공간, 1: 경로, 2: 장애물)
    protected ShapeRenderer shapeRenderer;
    protected Array<Enemy> enemies;
    protected Array<Tower> towers;
    protected Array<Wave> waves;
    private int currentWaveIndex;
    protected Wave currentWave;
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    
    protected Stage uiStage;
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected int gridSize = 64;
    protected Array<Obstacle> pathVisuals;
    private TextButton spawnButton;
    private TextButton.TextButtonStyle buttonStyle;
    private Skin skin;
    protected float offsetY = 0;
    protected AStarPathfinding aStar;  // AStar 경로 탐색
    protected int life = 10;  // 초기 Life 설정

    // 맵의 크기 (gridWidth, gridHeight)
    protected int mapWidth;  // 예시: 맵의 가로 크기
    protected int mapHeight; // 예시: 맵의 세로 크기
    // 소환할 수 있는 타워 리스트
    protected Array<Tower> availableTowers;
    private Array<Vector2> spawnablePositions;
    // 소환 가능한 타워의 영역을 확인
    protected boolean canSpawnTowerAt(float x, float y) {
        for (Tower tower : towers) {
            if (tower.getPosition().x == x && tower.getPosition().y == y) {
                return false;
            }
        }

        return true; 
    }
    private float buttonCooldownTime = 0.5f;  // 버튼 재사용 대기 시간 (초 단위)
    private float timeSinceLastButtonPress = 0f;  // 마지막 버튼 입력 이후 경과 시간

    // 타워 소환 메서드
    public void spawnTower() {
        Array<Vector2> filteredPositions = new Array<>();

        // 필터링
        for (Vector2 position : spawnablePositions) {
            if (canSpawnTowerAt(position.x, position.y)) {
                filteredPositions.add(position);
            }
        }

        if (filteredPositions.size > 0) {
            // 랜덤하게 위치 선택
            Vector2 selectedPosition = filteredPositions.random();

            // 타워 배치
            Tower towerToSpawn = new Tower(availableTowers.random());
            towerToSpawn.setPosition(selectedPosition);
            towers.add(towerToSpawn);
        } else {
            System.out.println("No valid positions to spawn a tower!");
        }
    }

	private void initializeSpawnablePositions() {
	    spawnablePositions = new Array<>();
	    for (int y = 0; y < mapHeight; y++) {
	        for (int x = 0; x < mapWidth; x++) {
	            if (map[y][x] == 2) {
	                float adjustedY = offsetY + y * gridSize;
	                spawnablePositions.add(new Vector2(x * gridSize, adjustedY));
	            }
	        }
	    }
	}
    // Wave 관리 및 처리
    protected void setupWave(Wave wave) {
        waves.add(wave);
    }

    // 웨이브 업데이트 메서드
    private void updateWave(float delta) {
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
    private void checkWaveCompletion() {
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
    public StageParent() {
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        towers = new Array<>();
        
        enemies = new Array<>();
        waves = new Array<>();
        currentWaveIndex = 0;
    }
    public void initialize() {
        uiStage = new Stage(new ScreenViewport());
        Gdx.input.setInputProcessor(uiStage);

        spawnButton = new TextButton("Spawn Tower", skin);
        spawnButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                spawnTower();
            }
        });

        Table uiTable = new Table();
        uiTable.setFillParent(true);
        uiTable.bottom();
        uiTable.add(spawnButton).width(200).height(60).pad(10);
        uiStage.addActor(uiTable);
        updateWave(Gdx.graphics.getDeltaTime());
        
        initializeSpawnablePositions();
    }

    public void render(SpriteBatch batch) {
        uiStage.act();
        uiStage.draw();
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
            int y = (int) ((obstacle.getY() - offsetY) / gridSize);  
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
