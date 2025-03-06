package io.github.chw3021.companydefense.screens.menu;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.ui.Window;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;

public class SettingScreenPopup extends Window {
    public SettingScreenPopup(Skin skin) {
        super("메뉴", skin);
        this.setSize(300, 400);
        this.setPosition(Gdx.graphics.getWidth() / 2f - 150, Gdx.graphics.getHeight() / 2f - 200);
        
        this.row();
        this.add(createButton("음량", skin, () -> System.out.println("음량")));
        this.row();
        this.add(createButton("계정탈퇴", skin, () -> System.out.println("계정탈퇴")));

        this.setModal(true);
    }

    private TextButton createButton(String text, Skin skin, Runnable action) {
        TextButton button = new TextButton(text, skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                action.run();
            }
        });
        return button;
    }
}
