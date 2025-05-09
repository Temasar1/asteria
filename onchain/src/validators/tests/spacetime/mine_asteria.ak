use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use asteria/test_mock as mock
use asteria/types.{AssetClass, Mine, MineAsteria, ShipDatum, Speed}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{add, from_asset, from_lovelace, zero}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Spend, Transaction,
}
use spacetime

// ==============================================================================================
// MineAsteria Tests
// ==============================================================================================

type MineTestOptions {
  ship_pos_x: Int,
  ship_pos_y: Int,
  output_ship_token_amount: Int,
  includes_ship_token: Bool,
  includes_pilot_token: Bool,
  includes_asteria_input: Bool,
  burns_ship_token: Bool,
  burns_fuel_tokens: Bool,
  respects_latest_time: Bool,
  excludes_extra_asteria_input: Bool,
}

fn default_mine_options() {
  MineTestOptions {
    ship_pos_x: 0,
    ship_pos_y: 0,
    output_ship_token_amount: 1,
    includes_ship_token: True,
    includes_pilot_token: True,
    includes_asteria_input: True,
    burns_ship_token: True,
    burns_fuel_tokens: True,
    respects_latest_time: True,
    excludes_extra_asteria_input: True,
  }
}

fn mine(options: MineTestOptions) -> Bool {
  let min_ada = from_lovelace(2_000_000)
  let fuel_per_step = 1
  let max_ship_fuel = 100
  let ship_fuel = 30
  let max_speed = Speed { distance: 1, time: 1_000 }
  let earliest_time =
    if options.respects_latest_time {
      10_000
    } else {
      0
    }
  let latest_time = earliest_time + 20_000
  let last_move_latest_time = 5_000
  let admin_token =
    AssetClass { policy: mock.admin_policy, name: mock.admin_token_name }
  let redeemer = MineAsteria
  let pilot_address =
    Address {
      payment_credential: VerificationKey(mock.pilot_credential),
      stake_credential: None,
    }
  let asteria_address =
    Address {
      payment_credential: Script(mock.asteria_credential),
      stake_credential: None,
    }
  let asteria_input = {
    let output =
      Output {
        address: asteria_address,
        value: from_lovelace(7_000_000)
          |> add(mock.admin_policy, mock.admin_token_name, 1),
        datum: NoDatum,
        reference_script: None,
      }
    let output_reference =
      OutputReference { transaction_id: mock.transaction_id_2, output_index: 0 }
    Input { output_reference, output }
  }
  let ship_address =
    Address {
      payment_credential: Script(mock.ship_credential),
      stake_credential: None,
    }
  let ship_input_value =
    min_ada
      |> add(mock.shipyard_policy, mock.ship_token_name, 1)
      |> add(mock.pellet_credential, "FUEL", ship_fuel)
  let ship_input_datum =
    ShipDatum {
      pos_x: options.ship_pos_x,
      pos_y: options.ship_pos_y,
      ship_token_name: mock.ship_token_name,
      pilot_token_name: mock.pilot_token_name,
      last_move_latest_time,
    }
  let ship_input = {
    let output =
      Output {
        address: ship_address,
        value: ship_input_value,
        datum: InlineDatum(ship_input_datum),
        reference_script: None,
      }
    let output_reference =
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 0 }
    Input { output_reference, output }
  }
  let pilot_input = {
    let output = {
      let value =
        if options.includes_pilot_token {
          min_ada
            |> add(mock.shipyard_policy, mock.pilot_token_name, 1)
        } else {
          min_ada
        }
      Output {
        address: pilot_address,
        value,
        datum: NoDatum,
        reference_script: None,
      }
    }
    let output_reference =
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 1 }
    Input { output_reference, output }
  }
  let extra_asteria_input = {
    let output =
      Output {
        address: asteria_address,
        value: zero,
        datum: NoDatum,
        reference_script: None,
      }
    let output_reference =
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 0 }
    Input { output_reference, output }
  }
  let tx =
    Transaction {
      inputs: if options.includes_asteria_input {
        if options.excludes_extra_asteria_input {
          [ship_input, pilot_input, asteria_input]
        } else {
          [ship_input, pilot_input, asteria_input, extra_asteria_input]
        }
      } else {
        [ship_input, pilot_input]
      },
      reference_inputs: [],
      outputs: [],
      fee: 5_000,
      mint: if options.burns_ship_token {
        if options.burns_fuel_tokens {
          from_asset(mock.shipyard_policy, mock.ship_token_name, -1)
            |> add(mock.pellet_credential, "FUEL", -ship_fuel)
        } else {
          from_asset(mock.shipyard_policy, mock.ship_token_name, -1)
        }
      } else {
        zero
      },
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(earliest_time),
          is_inclusive: True,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(latest_time),
          is_inclusive: True,
        },
      },
      extra_signatories: [],
      // FIXME: Two mint redeemers missing here!
      redeemers: [
        Pair(
          Spend(asteria_input.output_reference),
          {
            let redeemer_data: Data = Mine
            redeemer_data
          },
        ),
        Pair(
          Spend(ship_input.output_reference),
          {
            let redeemer_data: Data = MineAsteria
            redeemer_data
          },
        ),
      ],
      datums: dict.empty
        |> dict.insert(
            mock.transaction_id_1,
            {
              let datum_data: Data = InlineDatum(ship_input_datum)
              datum_data
            },
          ),
      id: mock.transaction_id_3,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let result =
    spacetime.spacetime.spend(
      mock.pellet_credential,
      mock.asteria_credential,
      admin_token,
      max_speed,
      max_ship_fuel,
      fuel_per_step,
      Some(ship_input_datum),
      redeemer,
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 0 },
      tx,
    )
  result
}

test mine_ok() {
  mine(default_mine_options())
}

test no_asteria_input() fail {
  mine(
    MineTestOptions { ..default_mine_options(), includes_asteria_input: False },
  )
}

test more_than_2_script_inputs() fail {
  mine(
    MineTestOptions {
      ..default_mine_options(),
      excludes_extra_asteria_input: False,
    },
  )
}

test no_pilot_token() fail {
  mine(
    MineTestOptions { ..default_mine_options(), includes_pilot_token: False },
  )
}
