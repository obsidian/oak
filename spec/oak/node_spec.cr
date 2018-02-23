require "../spec_helper"

record Payload

module Oak
  describe Node do
    describe "#glob?" do
      it "returns true when key contains a glob parameter (catch all)" do
        tree = Node(Nil).new("a")
        tree.glob?.should be_false

        tree = Node(Nil).new("*filepath")
        tree.glob?.should be_true
      end
    end

    describe "#key=" do
      it "accepts change of key after initialization" do
        tree = Node(Nil).new("abc")
        tree.key.should eq("abc")

        tree.key = "xyz"
        tree.key.should eq("xyz")
      end

      it "also changes kind when modified" do
        tree = Node(Nil).new("abc")
        tree.normal?.should be_true

        tree.key = ":query"
        tree.normal?.should be_false
        tree.named?.should be_true
      end
    end

    describe "#named?" do
      it "returns true when key contains a named parameter" do
        tree = Node(Nil).new("a")
        tree.named?.should be_false

        tree = Node(Nil).new(":query")
        tree.named?.should be_true
      end
    end

    describe "#normal?" do
      it "returns true when key does not contain named or glob parameters" do
        tree = Node(Nil).new("a")
        tree.normal?.should be_true

        tree = Node(Nil).new(":query")
        tree.normal?.should be_false

        tree = Node(Nil).new("*filepath")
        tree.normal?.should be_false
      end
    end

    describe "#payloads" do
      it "accepts any form of payload" do
        tree = Node.new("abc", :payload)
        tree.payloads?.should be_truthy
        tree.payloads.should contain(:payload)

        tree = Node.new("abc", 1_000)
        tree.payloads?.should be_truthy
        tree.payloads.should contain(1_000)
      end

      # This example focuses on the internal representation of `payload`
      # as inferred from supplied types and default values.
      #
      # We cannot compare `typeof` against `property!` since it excludes `Nil`
      # from the possible types.
      it "makes optional to provide a payload" do
        tree = Node(Int32).new("abc")
        tree.payloads?.should be_falsey
        # typeof(tree.payloads).should co ntain(Int32 | Nil)
      end
    end

    describe "#priority" do
      it "calculates it based on key length" do
        tree = Node(Nil).new("a")
        tree.priority.should eq(1)

        tree = Node(Nil).new("abc")
        tree.priority.should eq(3)
      end

      it "considers key length up until named parameter presence" do
        tree = Node(Nil).new("/posts/:id")
        tree.priority.should eq(7)

        tree = Node(Nil).new("/u/:username")
        tree.priority.should eq(3)
      end

      it "considers key length up until glob parameter presence" do
        tree = Node(Nil).new("/search/*query")
        tree.priority.should eq(8)

        tree = Node(Nil).new("/*anything")
        tree.priority.should eq(1)
      end

      it "changes when key changes" do
        tree = Node(Nil).new("a")
        tree.priority.should eq(1)

        tree.key = "abc"
        tree.priority.should eq(3)

        tree.key = "/src/*filepath"
        tree.priority.should eq(5)

        tree.key = "/search/:query"
        tree.priority.should eq(8)
      end
    end

    describe "#sort!" do
      it "orders children" do
        root = Node(Int32).new("/")
        tree1 = Node(Int32).new("a", 1)
        tree2 = Node(Int32).new("bc", 2)
        tree3 = Node(Int32).new("def", 3)

        root.children.push(tree1, tree2, tree3)
        root.sort!

        root.children[0].should eq(tree3)
        root.children[1].should eq(tree2)
        root.children[2].should eq(tree1)
      end

      it "orders catch all and named parameters lower than normal trees" do
        root = Node(Int32).new("/")
        tree1 = Node(Int32).new("*filepath", 1)
        tree2 = Node(Int32).new("abc", 2)
        tree3 = Node(Int32).new(":query", 3)

        root.children.push(tree1, tree2, tree3)
        root.sort!

        root.children[0].should eq(tree2)
        root.children[1].should eq(tree3)
        root.children[2].should eq(tree1)
      end
    end

    context "a new instance" do
      it "contains a root placeholder node" do
        tree = Node(Symbol).new
        tree.should be_a(Node(Symbol))
        tree.payloads?.should be_falsey
        tree.placeholder?.should be_true
      end
    end

    describe "#add" do
      context "on a new instance" do
        it "replaces placeholder with new node" do
          tree = Node(Symbol).new
          tree.add "/abc", :abc
          tree.should be_a(Node(Symbol))
          tree.placeholder?.should be_false
          tree.payloads?.should be_truthy
          tree.payloads.should contain(:abc)
        end
      end

      context "shared root" do
        it "inserts properly adjacent nodes" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/a", :a
          tree.add "/bc", :bc

          # /    (:root)
          # +-bc (:bc)
          # \-a  (:a)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("bc")
          tree.children[0].payloads.should contain(:bc)
          tree.children[1].key.should eq("a")
          tree.children[1].payloads.should contain(:a)
        end

        it "inserts nodes with shared parent" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/abc", :abc
          tree.add "/axyz", :axyz

          # /       (:root)
          # +-a
          #   +-xyz (:axyz)
          #   \-bc  (:abc)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq("a")
          tree.children[0].children.size.should eq(2)
          tree.children[0].children[0].key.should eq("xyz")
          tree.children[0].children[1].key.should eq("bc")
        end

        it "inserts multiple parent nodes" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/admin/users", :users
          tree.add "/admin/products", :products
          tree.add "/blog/tags", :tags
          tree.add "/blog/articles", :articles

          # /                 (:root)
          # +-admin/
          # |      +-products (:products)
          # |      \-users    (:users)
          # |
          # +-blog/
          #       +-articles  (:articles)
          #       \-tags      (:tags)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("admin/")
          tree.children[0].payloads?.should be_falsey
          tree.children[0].children[0].key.should eq("products")
          tree.children[0].children[1].key.should eq("users")
          tree.children[1].key.should eq("blog/")
          tree.children[1].payloads?.should be_falsey
          tree.children[1].children[0].key.should eq("articles")
          tree.children[1].children[0].payloads?.should be_truthy
          tree.children[1].children[1].key.should eq("tags")
          tree.children[1].children[1].payloads?.should be_truthy
        end

        it "inserts multiple nodes with mixed parents" do
          tree = Node(Symbol).new
          tree.add "/authorizations", :authorizations
          tree.add "/authorizations/:id", :authorization
          tree.add "/applications", :applications
          tree.add "/events", :events

          # /
          # +-events               (:events)
          # +-a
          #   +-uthorizations      (:authorizations)
          #   |             \-/:id (:authorization)
          #   \-pplications        (:applications)
          tree.children.size.should eq(2)
          tree.children[1].key.should eq("a")
          tree.children[1].children.size.should eq(2)
          tree.children[1].children[0].payloads.should contain(:authorizations)
          tree.children[1].children[1].payloads.should contain(:applications)
        end

        it "supports insertion of mixed routes out of order" do
          tree = Node(Symbol).new
          tree.add "/user/repos", :my_repos
          tree.add "/users/:user/repos", :user_repos
          tree.add "/users/:user", :user
          tree.add "/user", :me

          # /user                (:me)
          #     +-/repos         (:my_repos)
          #     \-s/:user        (:user)
          #             \-/repos (:user_repos)
          tree.key.should eq("/user")
          tree.payloads?.should be_truthy
          tree.payloads.should contain(:me)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("/repos")
          tree.children[1].key.should eq("s/:user")
          tree.children[1].payloads.should contain(:user)
          tree.children[1].children[0].key.should eq("/repos")
        end
      end

      context "mixed payloads" do
        it "allows node with different payloads" do
          payload1 = Payload.new
          payload2 = Payload.new

          tree = Node(Payload | Symbol).new
          tree.add "/", :root
          tree.add "/a", payload1
          tree.add "/bc", payload2

          # /    (:root)
          # +-bc (payload2)
          # \-a  (payload1)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("bc")
          tree.children[0].payloads.should contain(payload2)
          tree.children[1].key.should eq("a")
          tree.children[1].payloads.should contain(payload1)
        end
      end

      context "dealing with unicode" do
        it "inserts properly adjacent parent nodes" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/日本語", :japanese
          tree.add "/素晴らしい", :amazing

          # /          (:root)
          # +-素晴らしい    (:amazing)
          # \-日本語      (:japanese)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("素晴らしい")
          tree.children[1].key.should eq("日本語")
        end

        it "inserts nodes with shared parent" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/日本語", :japanese
          tree.add "/日本は難しい", :japanese_is_difficult

          # /                (:root)
          # \-日本語            (:japanese)
          #     \-日本は難しい     (:japanese_is_difficult)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq("日本")
          tree.children[0].children.size.should eq(2)
          tree.children[0].children[0].key.should eq("は難しい")
          tree.children[0].children[1].key.should eq("語")
        end
      end

      context "dealing with catch all and named parameters" do
        it "prioritizes nodes correctly" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit
          tree.add "/products/featured", :featured

          # /                      (:all)
          # +-products             (:products)
          # |        \-/
          # |          +-featured  (:featured)
          # |          \-:id       (:product)
          # |              \-/edit (:edit)
          # \-*filepath            (:all)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("products")
          tree.children[0].children[0].key.should eq("/")

          nodes = tree.children[0].children[0].children
          nodes.size.should eq(2)
          nodes[0].key.should eq("featured")
          nodes[1].key.should eq(":id")
          nodes[1].children[0].key.should eq("/edit")

          tree.children[1].key.should eq("*filepath")
        end

        it "does not split named parameters across shared key" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/:category", :category
          tree.add "/:category/:subcategory", :subcategory

          # /                         (:root)
          # +-:category               (:category)
          #           \-/:subcategory (:subcategory)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq(":category")

          # inner children
          tree.children[0].children.size.should eq(1)
          tree.children[0].children[0].key.should eq("/:subcategory")
        end

        it "does allow same named parameter in different order of insertion" do
          tree = Node(Symbol).new
          tree.add "/members/:id/edit", :member_edit
          tree.add "/members/export", :members_export
          tree.add "/members/:id/videos", :member_videos

          # /members/
          #         +-export      (:members_export)
          #         \-:id/
          #              +-videos (:members_videos)
          #              \-edit   (:members_edit)
          tree.key.should eq("/members/")
          tree.children.size.should eq(2)

          # first level children nodes
          tree.children[0].key.should eq("export")
          tree.children[1].key.should eq(":id/")

          # inner children
          nodes = tree.children[1].children
          nodes[0].key.should eq("videos")
          nodes[1].key.should eq("edit")
        end

        it "does not allow different named parameters sharing same level" do
          tree = Node(Symbol).new
          tree.add "/", :root
          tree.add "/:post", :post

          expect_raises Node::SharedKeyError do
            tree.add "/:category/:post", :category_post
          end
        end

        # TODO: uncomment when the shared key issue is overcome
        # it "allows different named parameters sharing same level" do
        #   tree = Node(Symbol).new
        #   tree.add "/", :root
        #   tree.add "/c-:post", :post
        #   tree.add "/c-:category/p-:post", :category_post
        #   tree.add "/c-:category/p-:poll/:id", :category_poll
        #   puts tree.visualize
        #
        #   results = tree.search("/c-1")
        #   puts results.map(&.key)
        #   results.size.should eq 1
        #   results.first.payloads.size.should eq 1
        #   results.first.params.should eq({ "post" => "1" })
        #   results.first.payloads.first.should eq :post
        #
        #   results = tree.search("/a/b")
        #   results.size.should eq 1
        #   results.first.payloads.size.should eq 1
        #   results.first.params.should eq({ "category" => "a", "post" => "b" })
        #   results.first.payloads.first.should eq :category_post
        # end
      end
    end
  end
end
