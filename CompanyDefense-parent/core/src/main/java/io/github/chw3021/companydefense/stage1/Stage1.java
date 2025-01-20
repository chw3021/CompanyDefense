package io.github.chw3021.companydefense.stage1;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.stage.Stage;
import io.github.chw3021.companydefense.tower.Tower;

import com.badlogic.gdx.InputAdapter;
public class Stage1 extends Stage {

    @Override
    public void initialize() {
        batch = new SpriteBatch();
        shapeRenderer = new ShapeRenderer();
        background = new Texture(Gdx.files.internal("space_background.png"));

        enemies = new Array<>();

        towers = new Array<>();
        Gdx.input.setInputProcessor(new InputAdapter() {
            @Override
            public boolean touchDown(int screenX, int screenY, int pointer, int button) {
                if (button == Input.Buttons.LEFT) {
                    int gridX = screenX / gridSize * gridSize;
                    int gridY = (Gdx.graphics.getHeight() - screenY) / gridSize * gridSize;
                    towers.add(new Tower(gridX, gridY));
                    return true;
                }
                return false;
            }
        });
    }

    @Override
    public void render(float delta) {
        batch.begin();
        batch.draw(background, 0, 0, Gdx.graphics.getWidth(), Gdx.graphics.getHeight());

        // 적 업데이트 및 렌더링
        for (Enemy enemy : enemies) {
        }

        // 타워 렌더링
        for (Tower tower : towers) {
            tower.render(batch);
        }

        batch.end();

        // 그리드 렌더링
        shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
        shapeRenderer.setColor(0, 1, 0, 1); // 녹색 그리드
        for (int x = 0; x < Gdx.graphics.getWidth(); x += gridSize) {
            for (int y = 0; y < Gdx.graphics.getHeight(); y += gridSize) {
                shapeRenderer.rect(x, y, gridSize, gridSize);
            }
        }
        shapeRenderer.end();
    }
}
