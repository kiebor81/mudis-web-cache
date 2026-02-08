# frozen_string_literal: true

RSpec.describe MudisWebCache::App do
  let(:secret) { "test-secret" }

  def auth_header(token)
    { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
  end

  def set_jwt_env
    ENV["MUDIS_JWT_ENABLED"] = "true"
    ENV["MUDIS_JWT_SECRET"] = secret
  end

  describe "JWT enforcement" do
    it "allows health without auth" do
      ENV["MUDIS_JWT_ENABLED"] = "true"
      get "/health"
      expect(last_response.status).to eq(200)
    end

    it "rejects requests when JWT enabled and token missing" do
      set_jwt_env
      get "/metrics"
      expect(last_response.status).to eq(401)
      expect(json_body["error"]).to match(/missing bearer token/i)
    end

    it "rejects requests when JWT secret missing" do
      ENV["MUDIS_JWT_ENABLED"] = "true"
      get "/metrics", {}, auth_header(jwt_token({ sub: "svc" }))
      expect(last_response.status).to eq(500)
      expect(json_body["error"]).to match(/secret not configured/i)
    end

    it "allows requests when JWT disabled" do
      ENV["MUDIS_JWT_ENABLED"] = "false"
      get "/metrics"
      expect(last_response.status).to eq(200)
    end
  end

  describe "JWT validation options" do
    it "enforces issuer and audience when configured" do
      set_jwt_env
      ENV["MUDIS_JWT_ISSUER"] = "issuer-1"
      ENV["MUDIS_JWT_AUDIENCE"] = "aud-1"

      token = jwt_token({ sub: "svc", iss: "issuer-1", aud: "aud-1" }, secret: secret)
      get "/metrics", {}, auth_header(token)
      expect(last_response.status).to eq(200)

      bad = jwt_token({ sub: "svc", iss: "issuer-2", aud: "aud-1" }, secret: secret)
      get "/metrics", {}, auth_header(bad)
      expect(last_response.status).to eq(401)
    end
  end

  describe "JWT expiry" do
    it "returns token expired when exp is in the past" do
      set_jwt_env
      token = jwt_token({ sub: "svc", exp: Time.now.to_i - 10 }, secret: secret)
      get "/metrics", {}, auth_header(token)
      expect(last_response.status).to eq(401)
      expect(json_body["error"]).to match(/token expired/i)
    end
  end

  describe "Admin endpoints" do
    it "requires admin claim for reset endpoints" do
      set_jwt_env
      token = jwt_token({ sub: "svc", role: "user" }, secret: secret)
      post "/reset", {}, auth_header(token)
      expect(last_response.status).to eq(403)

      admin = jwt_token({ sub: "svc", role: "admin" }, secret: secret)
      post "/reset", {}, auth_header(admin)
      expect(last_response.status).to eq(200)

      post "/metrics/reset", {}, auth_header(token)
      expect(last_response.status).to eq(403)
      post "/metrics/reset", {}, auth_header(admin)
      expect(last_response.status).to eq(200)
    end

    it "requires admin claim for namespace delete" do
      set_jwt_env
      token = jwt_token({ sub: "svc", role: "user" }, secret: secret)
      delete "/namespace/users", {}, auth_header(token)
      expect(last_response.status).to eq(403)

      admin = jwt_token({ sub: "svc", role: "admin" }, secret: secret)
      delete "/namespace/users", {}, auth_header(admin)
      expect(last_response.status).to eq(200)
    end
  end

  describe "Binding (opt-in)" do
    before do
      set_jwt_env
      ENV["MUDIS_BIND_ENABLED"] = "true"
      ENV["MUDIS_BIND_NAMESPACE_CLAIM"] = "sub"
      ENV["MUDIS_BIND_PREFIX"] = "caller:"
    end

    it "rejects when bind claim is missing" do
      token = jwt_token({ role: "admin" }, secret: secret)
      get "/cache/item-1", {}, auth_header(token)
      expect(last_response.status).to eq(403)
      expect(json_body["error"]).to match(/missing bind claim/i)
    end

    it "derives namespace from claim and ignores mismatched namespace" do
      token = jwt_token({ sub: "acme", role: "admin" }, secret: secret)
      post "/cache/user:1?namespace=other",
           { value: { name: "Ada" } }.to_json,
           auth_header(token).merge("CONTENT_TYPE" => "application/json")
      expect(last_response.status).to eq(403)

      post "/cache/user:1",
           { value: { name: "Ada" } }.to_json,
           auth_header(token).merge("CONTENT_TYPE" => "application/json")
      expect(last_response.status).to eq(200)

      get "/cache/user:1", {}, auth_header(token)
      expect(last_response.status).to eq(200)
      expect(json_body["value"]["name"]).to eq("Ada")
    end

    it "locks namespace deletes to the bound namespace" do
      token = jwt_token({ sub: "acme", role: "admin" }, secret: secret)
      delete "/namespace/other", {}, auth_header(token)
      expect(last_response.status).to eq(403)

      delete "/namespace/caller:acme", {}, auth_header(token)
      expect(last_response.status).to eq(200)
    end

    it "allows keys without namespace param when bound" do
      token = jwt_token({ sub: "acme", role: "admin" }, secret: secret)
      post "/cache/user:1",
           { value: "ok" }.to_json,
           auth_header(token).merge("CONTENT_TYPE" => "application/json")

      get "/keys", {}, auth_header(token)
      expect(last_response.status).to eq(200)
      expect(json_body["keys"]).to include("user:1")
    end
  end

  describe "No binding (default)" do
    it "requires namespace for keys endpoint" do
      set_jwt_env
      token = jwt_token({ sub: "svc" }, secret: secret)

      get "/keys", {}, auth_header(token)
      expect(last_response.status).to eq(400)
      expect(json_body["error"]).to match(/namespace is required/i)
    end
  end
end
