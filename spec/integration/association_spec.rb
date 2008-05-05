require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

begin
  gem 'do_sqlite3', '=0.9.0'
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  class Engine
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :name, String
  end

  class Yard
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :engine_id, Fixnum

    property :name, String

    repository(:sqlite3) do
      many_to_one :engine
    end
  end

  class Pie
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :sky_id, Fixnum

    property :name, String

    repository(:sqlite3) do
      one_to_one :sky
    end
  end

  class Sky
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :pie_id, Fixnum

    property :name, String

    repository(:sqlite3) do
      one_to_one :pie
    end
  end

  class Host
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :name, String

    repository(:sqlite3) do
      one_to_many :slices
    end
  end

  class Slice
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :host_id, Fixnum

    property :name, String

    repository(:sqlite3) do
      many_to_one :host
    end
  end

  describe DataMapper::Associations do
    describe "many to one associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Engine.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 1, 'engine1')
        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 2, 'engine2')

        Yard.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, ?)', 1, 'yard1', 1)
        @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, NULL)', 0, 'yard2')
      end

      it "should load without the parent"

      it 'should allow substituting the parent' do
        y = repository(:sqlite3).all(Yard, :id => 1).first
        e = repository(:sqlite3).all(Engine, :id => 2).first

        y.engine = e
        repository(:sqlite3).save(y)

        y = repository(:sqlite3).all(Yard, :id => 1).first
        y.engine_id.should == 2
      end

      it "#many_to_one" do
        yard = Yard.new
        yard.should respond_to(:engine)
        yard.should respond_to(:engine=)
      end

      it "should load the associated instance" do
        y = repository(:sqlite3).all(Yard, :id => 1).first
        y.engine.should_not be_nil
        y.engine.id.should == 1
        y.engine.name.should == "engine1"
      end

      it 'should save the association key in the child' do
        repository(:sqlite3) do
          e = repository(:sqlite3).all(Engine, :id => 2).first
          repository(:sqlite3).save(Yard.new(:id => 2, :name => 'yard2', :engine => e))
        end

        repository(:sqlite3).all(Yard, :id => 2).first.engine_id.should == 2
      end

      it 'should save the parent upon saving of child' do
        y = nil
        repository(:sqlite3) do |r|       
          e = Engine.new(:id => 10, :name => "engine10")
          y = Yard.new(:id => 10, :name => "Yard10", :engine => e)
          r.save(y)
        end

        y.engine_id.should == 10
        repository(:sqlite3).all(Engine, :id => 10).first.should_not be_nil
      end

      it 'should convert NULL parent ids into nils' do
        y = repository(:sqlite3).all(Yard, :id => 0).first
        y.engine.should be_nil
      end
 
      it 'should save nil parents as NULL ids' do
        y1,y2 = nil, nil

        repository(:sqlite3) do |r|
          y1 = Yard.new(:id => 20, :name => "Yard20")
          r.save(y1)

          y2 = Yard.create!(:id => 30, :name => "Yard30", :engine => nil)
        end

        y1.id.should == 20
        y1.engine_id.should be_nil
        y2.id.should == 30
        y2.engine_id.should be_nil
      end

      after do
        @adapter.execute('DROP TABLE "yards"')
        @adapter.execute('DROP TABLE "engines"')
      end
    end

    describe "one to one associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Sky.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "skies" ("id", "name") values (?, ?)', 1, 'sky1')

        Pie.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "pies" ("id", "name", "sky_id") values (?, ?, ?)', 1, 'pie1', 1)
        @adapter.execute('INSERT INTO "pies" ("id", "name") values (?, ?)', 2, 'pie2')
      end

      it 'should allow substituting the child' do
        s = repository(:sqlite3).all(Sky, :id => 1).first
        p = repository(:sqlite3).all(Pie, :id => 2).first

        s.pie = p

        p1 = repository(:sqlite3).first(Pie, :id => 1)
        p1.sky_id.should be_nil

        p2 = repository(:sqlite3).first(Pie, :id => 2)
        p2.sky_id.should == 1
      end

      it "#one_to_one" do
        s = Sky.new
        s.should respond_to(:pie)
        s.should respond_to(:pie=)
      end

      it "should load the associated instance" do
        s = repository(:sqlite3).first(Sky, :id => 1)
        s.pie.should_not be_nil
        s.pie.id.should == 1
        s.pie.name.should == "pie1"
      end

      it 'should save the association key in the child' do
        repository(:sqlite3) do |r|
          p = r.first(Pie, :id => 2)
          r.save(Sky.new(:id => 2, :name => 'sky2', :pie => p))
        end

        repository(:sqlite3).first(Pie, :id => 2).sky_id.should == 2
      end

      it 'should save the children upon saving of parent' do
        repository(:sqlite3) do |r|
          p = Pie.new(:id => 10, :name => "pie10")
          s = Sky.new(:id => 10, :name => "sky10", :pie => p)

          r.save(s)

          p.sky_id.should == 10
        end

        repository(:sqlite3).first(Pie, :id => 10).should_not be_nil
      end

      it 'should save nil parents as NULL ids' do
        p1,p2 = nil, nil

        repository(:sqlite3) do |r|
          p1 = Pie.new(:id => 20, :name => "Pie20")
          r.save(p1)

          p2 = Pie.create!(:id => 30, :name => "Pie30", :sky => nil)
        end

        p1.id.should == 20
        p1.sky_id.should be_nil
        p2.id.should == 30
        p2.sky_id.should be_nil
      end

      after do
        @adapter.execute('DROP TABLE "pies"')
        @adapter.execute('DROP TABLE "skies"')
      end
    end

    describe "one to many associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Host.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 1, 'host1')
        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 2, 'host2')

        Slice.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, NULL)', 0, 'slice0')
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 1, 'slice1', 1)
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 2, 'slice2', 1)
      end

      it "#one_to_many" do
        h = Host.new
        h.should respond_to(:slices)
      end

      it "should allow removal of a child through a loaded association" do
        h = repository(:sqlite3).all(Host, :id => 1).first
        s = h.slices.first

        h.slices.delete(s)
        h.slices.size.should == 1

        s = repository(:sqlite3).first(Slice, :id => s.id)
        s.host.should be_nil
        s.host_id.should be_nil
      end

      it "should load the associated instances" do
        h = repository(:sqlite3).all(Host, :id => 1).first
        h.slices.should_not be_nil
        h.slices.size.should == 2
        h.slices.first.id.should == 1
        h.slices.last.id.should == 2

        s0 = repository(:sqlite3).all(Slice, :id => 0).first
        s0.host.should be_nil
        s0.host_id.should be_nil
      end

      it "should add and save the associated instance" do
        h = repository(:sqlite3).all(Host, :id => 1).first
        h.slices << Slice.new(:id => 3, :name => 'slice3')

        s = repository(:sqlite3).all(Slice, :id => 3).first
        s.host.id.should == 1
      end

      it "should not save the associated instance if the parent is not saved" do
        repository(:sqlite3) do
          h = Host.new(:id => 10, :name => "host10")
          h.slices << Slice.new(:id => 10, :name => 'slice10')
        end

        repository(:sqlite3).all(Slice, :id => 10).first.should be_nil
      end

      it "should save the associated instance upon saving of parent" do
        repository(:sqlite3) do |r|
          h = Host.new(:id => 10, :name => "host10")
          h.slices << Slice.new(:id => 10, :name => 'slice10')
          r.save(h)
        end

        s = repository(:sqlite3).all(Slice, :id => 10).first
        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end

      describe '#through' do
        before(:all) do
          module Sweets
            class Shop
              include DataMapper::Resource
              property :id, Fixnum, :serial => true
              property :name, String
              has n, :cakes, :class_name => 'Sweets::Cake'
              has n, :slices => :cakes
            end
            
            class Cake
              include DataMapper::Resource
              property :id, Fixnum, :serial => true
              property :name, String
              has n, :slices, :class_name => 'Sweets::Slice'
            end
            
            class Slice
              include DataMapper::Resource
              property :id, Fixnum, :serial => true
              property :size, Fixnum
              belongs_to :cake, :class_name => 'Sweets::Cake'
            end
            
            # repository(:sqlite3) do
            #   Shop.auto_migrate!(:sqlite3)
            #   Cake.auto_migrate!(:sqlite3)
            #   Slice.auto_migrate!(:sqlite3)
            # 
            #   betsys = Shop.new(:name => "Betsy's")
            #   german_chocolate = betsys.cakes << Cake.new(:name => 'German Chocolate')
            #   10.times { |i| german_chocolate.slices << Slice.new(:size => i) }
            # 
            #   short_cake = betsys.cakes << Cake.new(:name => 'Short Cake')
            #   5.times { |i| short_cake.slices << Slice.new(:size => i) }
            # 
            #   betsys.save!
            # end
          end
        end

        it "should be amazing" do
          pending
          Sweets::Shop.first.cakes.should have(2).entries
        end
      end
    end
  end
rescue LoadError
  warn "integration/association_spec not run! Could not load do_sqlite3."
end
