use cardano/assets.{AssetName, PolicyId}

pub type PosixTime =
  Int

pub type AssetClass {
  policy: PolicyId,
  name: AssetName,
}

pub type Speed {
  distance: Int,
  time: Int,
}

pub type ShipDatum {
  pos_x: Int,
  pos_y: Int,
  ship_token_name: AssetName,
  pilot_token_name: AssetName,
  last_move_latest_time: PosixTime,
}

pub type ShipRedeemer {
  MoveShip { delta_x: Int, delta_y: Int }
  GatherFuel { amount: Int }
  MineAsteria
  Quit
}

pub type PelletDatum {
  pos_x: Int,
  pos_y: Int,
  shipyard_policy: PolicyId,
}

pub type PelletRedeemer {
  Provide { amount: Int }
  ConsumePellet
}

pub type AsteriaDatum {
  ship_counter: Int,
  shipyard_policy: PolicyId,
}

pub type AsteriaRedeemer {
  AddNewShip
  Mine
  ConsumeAsteria
}

pub type ShipyardRedeemer {
  MintShip
  BurnShip
}

pub type FuelRedeemer {
  MintFuel
  BurnFuel
}
