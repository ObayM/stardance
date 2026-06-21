class CreateCertificationShipSpotChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :certification_ship_spot_checks do |t|
      t.references :ship, null: false, foreign_key: { to_table: :certification_ship_reviews }
      t.references :checker, null: false, foreign_key: { to_table: :users }
      t.integer :rating, null: false, default: 0
      t.text :justification

      t.timestamps
    end

    add_index :certification_ship_spot_checks, :ship_id,
              unique: true, name: "index_ship_spot_checks_unique_per_ship"
  end
end
