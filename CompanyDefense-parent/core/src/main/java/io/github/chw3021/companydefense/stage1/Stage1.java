package io.github.chw3021.companydefense.stage1;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.screens.LoadingScreenManager;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.stage.Wave;
import io.github.chw3021.companydefense.tower.Tower;
public class Stage1 extends StageParent {
    public Stage1(Game game) {
        super(game);
        initialize();
    }

	private Wave createFirstWave() {
	    Wave wave = new Wave(0.2f);
        for(int i = 0; i<20; i++) {
        	Enemy printer = generateEnemy(50, 1, 1, 5, "normal", "enemy/printer.png");
        	wave.addEnemy(printer);
        	printer.setWave(wave);
        }
	    return wave;
	}
	
	private Wave createSecondWave() {
	    Wave wave = new Wave(2.0f);
        for(int i = 0; i<1; i++) {
        	Enemy printer = generateEnemy(99999999, 100, 100, 1, "boss", "enemy/printer.png");
        	wave.addEnemy(printer);
        	printer.setWave(wave);
        }
	    return wave;
	}
	
    @Override
    public void initialize() {
    	map = new float[][] {
    	    { 2.0f, 1.0f, 1.0f, 2.1f, 0.0f, 0.0f, 1.6f, 1.0f, 1.0f, 1.7f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.9f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.8f },
    	    { 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f },
    	    { 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f },
    	    { 1.2f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.3f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.1f, 0.0f, 0.0f, 2.2f, 0.0f, 0.0f, 1.5f, 1.0f, 1.0f, 1.4f },
    	};

        mapWidth = 10;  // 예시: 맵의 가로 크기
        mapHeight = 10; // 예시: 맵의 세로 크기
        gridSize = Gdx.graphics.getWidth() / mapWidth; // 화면 너비에 맞게 그리드 크기 설정

        // 배경 텍스처 로드
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.png"));

    	
    	
        //<a href="https://kr.freepik.com/free-vector/realistic-office-design-flat-lay_24007772.htm">작가 pikisuperstar 출처 Freepik</a>
        // 텍스처 로드
        Pixmap obstaclePixmap = new Pixmap(Gdx.files.internal("constructure/obstacle/obstacle.png"));
        //Pixmap pathPixmap = new Pixmap(Gdx.files.internal("constructure/path/path.png"));
        offsetY = Gdx.graphics.getHeight() - (mapHeight * gridSize);
        
        aStar = AStarPathfinding.getInstance(mapWidth, mapHeight, gridSize);
        aStar.setObstacles(map);
        
        // 장애물 추가
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                float adjustedY = offsetY + y * gridSize;
                if (map[y][x] == 0.0f) {
                    // 장애물 생성
                    addObstacle(new Obstacle(x * gridSize, adjustedY, obstaclePixmap, gridSize, gridSize));
                }
                if (map[y][x] == 1.1f) {
                	startX = x;
                	startY = y;
                }
                if (map[y][x] == 2.2f) {
                	endX = x;
                	endY = y;
                }
                
            }
        }


        Wave wave1 = createFirstWave();
        
        waveManager.addWave(wave1);
        waveManager.addWave(createSecondWave());

    	super.initialize();
    }

    @Override
    public void render(SpriteBatch batch, ShapeRenderer shapeRenderer) {
        super.render(batch, shapeRenderer);
    }
    @Override
    public void dispose() {
        super.dispose();
    }
}
