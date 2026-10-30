local VisualIndex = {
    sentry = {
        size = 15, barrel = 10, color = {1, 1, 1, 1}
    },
    blaster = {
        size = 15, barrel = 12, color = {0.2, 0.8, 1, 1},
        sfx = "laser_02"
    },
    autoCannon = {
        size = 15, barrel = 12, color = {0.6, 0.6, 0.6, 1},
        sfx = "gunshot_01"
    },
    shotgunTurret = {
        barrel = 10, color = {1, 0.4, 0, 1},
        baseShape = "square", barrelShape = "flared",
        sfx = "gunshot_03"
    },
    heavygun = {
        barrel = 12, color = {0.8, 0.4, 0.2, 1},
        baseShape = "square", barrelShape = "thick",
        sfx = "gunshot_02"
    },
    poisonTurret = {
        barrel = 12, color = {0.5, 1, 0.5, 1}
    },
    airburst = {
        barrel = 12, color = {1, 0.6, 0.2, 1},
        baseShape = "hexagon", barrelShape = "funnel",
        sfx = "gunshot_04"
    },
    fluxCannon = {
        barrel = 10, color = {0.6, 0.2, 1, 1},
        baseShape = "diamond", barrelShape = "double",
        sfx = "laser_02"
    },
    grenadier = {
        size = 15, barrel = 10, color = {0.3, 0.8, 0.3, 1},
        baseShape = "circle", barrelShape = "thick",
        sfx = "gunshot_04"
    },
    slushCannon = {
        barrel = 14, color = {0.8, 0.95, 1, 1},
        baseShape = "hexagon", barrelShape = "thick",
        sfx = "laser_02"
    },
    iceShard = {
        size = 15, barrel = 12, color = {0.55, 0.85, 1, 1},
        baseShape = "diamond", barrelShape = "single",
        sfx = "gunshot_01"
    },
    frostCannon = {
        barrel = 14, color = {0.75, 0.92, 1, 1},
        baseShape = "hexagon", barrelShape = "long",
        sfx = "gunshot_03"
    },
    glacialMonolith = {
        barrel = 4, color = {0.7, 0.9, 1, 1},
        baseShape = "square", barrelShape = "thick"
    },
    icicleBallista = {
        barrel = 15, color = {0.8, 0.95, 1, 1},
        baseShape = "square", barrelShape = "long",
        sfx = "gunshot_02"
    },
    cryoBeam = {
        barrel = 12, color = {0.85, 0.97, 1, 1},
        baseShape = "diamond", barrelShape = "single"
    },
    gator = {
        size = 18, barrel = 15, color = {0.15, 0.5, 0.15, 1},
        sfx = "gunshot_02"
    },
    missileLauncher = {
        barrel = 10, color = {0.7, 0.2, 0.9, 1},
        baseShape = "square", barrelShape = "single",
        sfx = "missile_01"
    },
    heavyShotgun = {
        barrel = 14, color = {0.85, 0.3, 0.05, 1},
        baseShape = "square", barrelShape = "long",
        sfx = "gunshot_02"
    },
    plasmaScattershot = {
        barrel = 10, color = {0.2, 0.6, 1, 1},
        baseShape = "square", barrelShape = "flared",
        sfx = "laser_02"
    },
    sequenceTurret = {
        barrel = 12, color = {0.2, 0.4, 0.8, 1},
        baseShape = "octagon", barrelShape = "single",
        sfx = "gunshot_01"
    },
    hookTurret = {
        barrel = 15, color = {0.7, 0.4, 0.4, 1}
    },
    sniper = {
        barrel = 12, color = {0.8, 0.2, 0.2, 1},
        baseShape = "diamond", barrelShape = "long",
        sfx = "gunshot_03"
    },
    mortar = {
        size = 15, barrel = 10, color = {1, 1, 1, 1},
        baseShape = "circle", barrelShape = "thick",
        sfx = "gunshot_04"
    },
    chainLaser = {
    },
    -- Fire synergy
    flareGun = {
        size = 15, barrel = 11, color = {1, 0.35, 0.35, 1},
        baseShape = "circle", barrelShape = "thick",
        sfx = "gunshot_01"
    },
    oilGun = {
        barrel = 12, color = {0.8, 0.65, 0.3, 1},
        baseShape = "hexagon", barrelShape = "thick",
        sfx = "gunshot_04"
    },
    flamethrower = {
        barrel = 12, color = {1, 0.5, 0.1, 1},
        baseShape = "square", barrelShape = "funnel",
        sfx = "gunshot_01"
    },
    cinderMortar = {
        size = 15, barrel = 10, color = {1, 0.4, 0.15, 1},
        baseShape = "circle", barrelShape = "flared",
        sfx = "gunshot_04"
    },
    thermiteLauncher = {
        barrel = 13, color = {1, 0.8, 0.5, 1},
        baseShape = "diamond", barrelShape = "double",
        sfx = "gunshot_02"
    },
    infernoTower = {
        barrel = 12, color = {1, 0.35, 0.05, 1},
        baseShape = "hexagon", barrelShape = "long"
    },
    meteor = {
        -- Satellite dish (MeteorTurret:drawCustomBarrel); fire point at the dish's receiver
        barrel = 12, color = {1, 0.55, 0.2, 1},
        baseShape = "square",
        sfx = "missile_01"
    }
}

return VisualIndex
