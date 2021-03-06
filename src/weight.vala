/* weight.vala
 *
 * Copyright 2020 Rasmus Thomsen <oss@cogitri.dev>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Health {
    public class Weight : GLib.Object {
        public GLib.Date date { get; private set; }
        public double weight { get; private set; }

        public Weight (GLib.Date date, double weight) {
            this.date = date;
            this.weight = weight;
        }

    }

    public class WeightGraphModel : GraphModel<Weight> {
        private Settings settings;

        public WeightGraphModel (Settings settings) {
            this.init ();

            this.settings = settings;
        }

        public override bool reload () {
            var db = new SqliteDatabase ();
            try {
                db.open ();
                this.arr = db.get_weights_after (get_date_in_n_days (-30));
                return true;
            } catch (DatabaseError e) {
                warning (_ ("Failed to load weights from database due to error %s"), e.message);
                return false;
            }
        }

        public override Gee.ArrayList<Point> to_points () {
            var ret = new Gee.ArrayList<Point> ();

            this.arr.sort ((a, b) => { return a.date.compare (b.date); });

            foreach (var weight in this.arr) {
                if (settings.unitsystem == Unitsystem.IMPERIAL) {
                    ret.add (new Point (weight.date, kg_to_pb (weight.weight)));
                } else {
                    ret.add (new Point (weight.date, weight.weight));
                }
            }

            return ret;
        }

        public double get_last_weight () {
            this.arr.sort ((a, b) => { return a.date.compare (b.date); });
            if (this.arr.is_empty) {
                return 0.0;
            }
            var last_weight = this.arr.get (this.arr.size - 1);
            return last_weight.weight;
        }

    }

    public class WeightGraphView : GraphView {
        public WeightGraphView (WeightGraphModel model) {
            base (model.to_points ());
            this.margin = 6;
        }

    }

    [GtkTemplate (ui = "/org/gnome/Health/weight_view.ui")]
    public class WeightView : View {
        [GtkChild]
        private Gtk.Label title_label;
        [GtkChild]
        private Gtk.Box main_box;
        private Gtk.Label no_data_label;
        private Settings settings;
        private WeightGraphView? weight_graph_view;
        private WeightGraphModel weight_graph_model;

        public WeightView (WeightGraphModel model, Settings settings) {
            this.name = "Weight";
            this.settings = settings;
            this.title = _ ("Weight");
            this.weight_graph_model = model;

            if (this.weight_graph_model.is_empty) {
                this.no_data_label = new Gtk.Label (_ ("No data has been added yet. Click + to add a new weight measurement."));
                this.main_box.pack_start (this.no_data_label);
            } else {
                this.weight_graph_view = new WeightGraphView (model);
                this.main_box.pack_start ((!) this.weight_graph_view);
            }

            this.update ();
            this.main_box.show_all ();
            this.settings.changed[Settings.USER_HEIGHT_KEY].connect (() => {
                this.update ();
            });
            this.settings.changed[Settings.UNITSYSTEM_KEY].connect (() => {
                this.update ();
            });
        }

        private double get_bmi () {
            return this.weight_graph_model.get_last_weight () / GLib.Math.pow (this.settings.user_height / 100.0, 2);
        }

        public override void update () {
            this.weight_graph_model.reload ();
            this.title_label.set_text (_ ("Current BMI: %.2lf").printf (this.get_bmi ()));

            if (this.weight_graph_view == null && !this.weight_graph_model.is_empty) {
                this.main_box.remove (this.no_data_label);
                this.weight_graph_view = new WeightGraphView (this.weight_graph_model);
                this.main_box.pack_start ((!) this.weight_graph_view);
            } else if (this.weight_graph_view != null) {
                ((!) this.weight_graph_view).points = this.weight_graph_model.to_points ();
            }
        }

    }
}
