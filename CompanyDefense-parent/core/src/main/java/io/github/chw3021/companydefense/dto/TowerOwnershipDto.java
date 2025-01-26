package io.github.chw3021.companydefense.dto;

public class TowerOwnershipDto {
    private String towerId;   // 타워의 ID
    private int towerLevel;   // 타워의 레벨

    public String getTowerId() {
        return towerId;
    }

    public void setTowerId(String towerId) {
        this.towerId = towerId;
    }

    public int getTowerLevel() {
        return towerLevel;
    }

    public void setTowerLevel(int towerLevel) {
        this.towerLevel = towerLevel;
    }
}
