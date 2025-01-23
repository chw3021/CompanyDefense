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
    protected WaveManager waveManager;
    protected Array<Enemy> activeEnemies;
    protected Array<Tower> towers;
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    
    protected Stage uiStage;
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected int gridSize = 64;
    protected Array<Obstacle> pathVisuals;
    private TextButton spawnButton;
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
	
    public StageParent() {
        super();
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        towers = new Array<>();

        waveManager = new WaveManager();
        waveManager.setStage(uiStage);
        activeEnemies = new Array<>();
    }
    
    @Override
    public void act(float delta) {
        super.act(delta);
        
        // Update enemies
        for (Enemy enemy : new Array.ArrayIterator<>(activeEnemies)) {
            enemy.update();
            
            // Check if enemy reached end
            if (enemyReachedEnd(enemy)) {
                handleEnemyExit(enemy);
            }
        }
        // 타워 공격 로직 추가
        for (Tower tower : towers) {
            tower.update(delta, activeEnemies); // 타워가 범위 내 적을 공격
        }

        // Update wave management
        waveManager.update(delta, this);
        waveManager.checkGameOver(this);
    }

    private boolean enemyReachedEnd(Enemy enemy) {
        // Implement logic to check if enemy reached end of path
        return false; // Placeholder
    }

    public Array<Enemy> getActiveEnemies() {
        return activeEnemies;
    }

    public void handleEnemyExit(Enemy enemy) {
        activeEnemies.removeValue(enemy, true);
        enemy.dispose();
        life--;
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
        
        initializeSpawnablePositions();
    }

    public void render(SpriteBatch batch) {
        uiStage.act();
        uiStage.draw();
    }
    public int getLife() {
    	return life;
    }

    // 장애물 추가 메서드
    public void addObstacle(Obstacle obstacle) {
        if (obstacles == null) {
            obstacles = new Array<>(); 
        }
        obstacles.add(obstacle);
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

