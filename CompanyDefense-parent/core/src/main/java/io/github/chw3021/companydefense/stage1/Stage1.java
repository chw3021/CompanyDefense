package io.github.chw3021.companydefense.stage1;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.stage.StageParrent;
import io.github.chw3021.companydefense.stage.Wave;
import io.github.chw3021.companydefense.tower.Tower;

import com.badlogic.gdx.InputAdapter;
public class Stage1 extends StageParrent {
    private Texture obstacleTexture;
    private Texture pathTexture;
    private Texture backgroundTexture;

    public Stage1() {
        super();
        initialize();
    }

    @Override
    public void initialize() {
        // 맵 데이터 초기화 (옆으로 누운 S자 경로)
    	map = new float[][] {
    	    { 2, 1, 1, 2, 2 },
    	    { 2, 1, 2, 2, 2 },
    	    { 2, 1, 1, 1, 1 },
    	    { 2, 2, 2, 1, 2 },
    	    { 2, 2, 2, 1, 1 }
    	};
        mapWidth = 5;  // 예시: 맵의 가로 크기
        mapHeight = 5; // 예시: 맵의 세로 크기
        //<a href="https://kr.freepik.com/free-vector/realistic-office-design-flat-lay_24007772.htm">작가 pikisuperstar 출처 Freepik</a>
        // 텍스처 로드
        Pixmap obstaclePixmap = new Pixmap(Gdx.files.internal("constructure/obstacle/obstacle.jpg"));
        Pixmap pathPixmap = new Pixmap(Gdx.files.internal("constructure/path/path.png"));
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.jpg"));
        float offsetY = Gdx.graphics.getHeight() - (mapHeight * gridSize);
        // 장애물 추가
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                float adjustedY = offsetY + y * gridSize;
                if (map[y][x] == 2) {
                    // 장애물 생성
                    addObstacle(new Obstacle(x * gridSize, adjustedY * gridSize, obstaclePixmap, gridSize, gridSize));
                } else if (map[y][x] == 1) {
                    // 경로를 시각적으로 표현하기 위해 텍스처를 배치
                    pathVisuals.add(new Obstacle(x * gridSize, adjustedY * gridSize, pathPixmap, gridSize, gridSize));
                }
            }
        }

        availableTowers = new Array<>();
        availableTowers.add(new Tower(0, 0, 10, 0, 1, 2, "tower/class1/man1.png", "man"));
        // A* 경로 설정
        setupAStar();

        // 적 웨이브 설정
        Array<Enemy> waveEnemies = new Array<>();
        waveEnemies.add(new Enemy(0, 2 * gridSize, 100, 5, 5, 100, "normal", "enemy/printer.png", new Vector2(9 * gridSize, 2 * gridSize)));
        Wave wave1 = new Wave(waveEnemies, waveTimeInterval);
        setupWave(wave1);
    	super.initialize();
    }

    @Override
    public void render(SpriteBatch batch) {
    	batch.begin();
        // 배경
        batch.draw(backgroundTexture, 0, Gdx.graphics.getHeight() / 4, Gdx.graphics.getWidth(), Gdx.graphics.getHeight() * 3 / 4);
        
        // 경로 및 장애물
        for (Obstacle path : pathVisuals) {
            path.render(batch);
        }
        for (Obstacle obstacle : obstacles) {
            obstacle.render(batch);
        }

        // 타워 및 적
        for (Tower tower : towers) {
            tower.render(batch);
        }
        for (Enemy enemy : enemies) {
            enemy.render(batch);
        }
        batch.end();

        super.render(batch);
        
    }
    @Override
    public void dispose() {
        super.dispose();
        obstacleTexture.dispose();
        pathTexture.dispose();
        backgroundTexture.dispose();
    }
}
