package io.github.chw3021.companydefense.dto;

public class EquipmentOwnershipDto {
    private String eqId;   // 장비의 ID
    private int eqLevel;   // 장비의 레벨

    public String getEqId() {
        return eqId;
    }

    public void setEqId(String eqId) {
        this.eqId = eqId;
    }

    public int getEqLevel() {
        return eqLevel;
    }

    public void setEqLevel(int eqLevel) {
        this.eqLevel = eqLevel;
    }
}
