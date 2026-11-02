require "rails_helper"

RSpec.describe JsonHttp do
  let(:url) { "https://api.example.test/data" }

  it "returns the parsed JSON body" do
    stub_request(:get, url).with(query: { "q" => "1 Main St #2 & Café" }).to_return(body: '{"ok":true}')

    expect(JsonHttp.get(url, q: "1 Main St #2 & Café")).to eq("ok" => true)
  end

  it "raises ServiceUnavailable on a non-2xx response" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_return(status: 500, body: "oops")

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable)
  end

  it "does not expose the upstream error reason" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_return(status: 400, body: '{"error":true,"reason":"bad latitude"}')

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable, ServiceUnavailable.new.message)
  end

  it "raises ServiceUnavailable on timeout" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_timeout

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable when the connection is refused" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_raise(Errno::ECONNREFUSED)

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable on invalid JSON" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_return(body: "<html>")

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable)
  end

  it "raises ServiceUnavailable on a malformed HTTP response" do
    stub_request(:get, url).with(query: { "q" => "x" }).to_raise(Net::HTTPBadResponse)

    expect { JsonHttp.get(url, q: "x") }.to raise_error(ServiceUnavailable)
  end
end
