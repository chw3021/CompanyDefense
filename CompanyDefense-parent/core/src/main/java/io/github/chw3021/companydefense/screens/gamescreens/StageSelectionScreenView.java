package io.github.chw3021.companydefense.screens.gamescreens;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;

public class StageSelectionScreenView extends Table {
    private Game game;
    private Skin skin;
    private float screenWidth;
    private float screenHeight;

    public StageSelectionScreenView(Game game) {
        this.game = game;
        this.setFillParent(true);
        skin = new Skin(Gdx.files.internal("ui/companyskin.json"));

        screenWidth = Gdx.graphics.getWidth();
        screenHeight = Gdx.graphics.getHeight();

        this.top().center(); // 레이아웃 정렬

        // 제목 추가
        Label title = new Label("스테이지 선택", skin);
        title.setColor(Color.BLACK);
        this.add(title).padBottom(screenHeight * 0.05f).row(); // 화면 높이의 5%

        // 스테이지 버튼 추가
        createButton("Easy", () -> game.setScreen(new GameScreen(game, 1)));
        createButton("Normal", () -> game.setScreen(new GameScreen(game, 2)));
        createButton("Hard", () -> game.setScreen(new GameScreen(game, 3)));
    }

    /** 버튼 생성 메서드 */
    private void createButton(String text, Runnable onClick) {
        TextButton button = new TextButton(text, skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run();
            }
        });
        this.add(button)
            .width(screenWidth * 0.35f)
            .height(screenHeight * 0.06f)   // 화면 높이의 10%
            .fillX()
            .uniformX()
            .pad(10)
            .row();
    }
}