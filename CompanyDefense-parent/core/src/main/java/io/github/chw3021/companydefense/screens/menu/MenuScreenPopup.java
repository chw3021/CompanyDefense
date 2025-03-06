package io.github.chw3021.companydefense.screens.menu;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.ui.Window;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;

public class MenuScreenPopup extends Window {
    public MenuScreenPopup(Skin skin) {
        super("메뉴", skin);
        this.setSize(Gdx.graphics.getWidth()*0.5f, Gdx.graphics.getHeight()*0.6f);
        this.setPosition(Gdx.graphics.getWidth()*0.25f, Gdx.graphics.getHeight()*0.3f);

        this.row();
        this.add(createButton("랭킹", skin, () -> System.out.println("랭킹")));
        this.row();
        this.add(createButton("우편함", skin, () -> System.out.println("우편함")));

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
