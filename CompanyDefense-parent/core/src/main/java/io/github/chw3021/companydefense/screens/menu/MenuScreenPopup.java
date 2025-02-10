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
        this.setSize(300, 400);
        this.setPosition(Gdx.graphics.getWidth() / 2f - 150, Gdx.graphics.getHeight() / 2f - 200);

        // 버튼 추가
        this.add(createButton("설정", skin, () -> System.out.println("설정 화면")));
        this.row();
        this.add(createButton("공지사항", skin, () -> System.out.println("공지사항")));
        this.row();
        this.add(createButton("랭킹", skin, () -> System.out.println("랭킹")));
        this.row();
        this.add(createButton("우편함", skin, () -> System.out.println("우편함")));
        this.row();
        this.add(createButton("커뮤니티", skin, () -> System.out.println("커뮤니티")));

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
