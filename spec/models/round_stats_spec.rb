require 'spec_helper'

describe RoundStats do
  let(:channel) { Fabricate(:channel) }

  before do
    allow(channel).to receive(:sync!)
    allow(channel).to receive(:inform!)
    allow_any_instance_of(Sup).to receive(:dm!)
  end

  context 'with users in a sup' do
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:round) { channel.sup! }

    let(:stats) { described_class.new(round) }

    it 'to_s' do
      expect(stats.to_s).to eq "* in progress: 1 S'Up paired 2 users and no outcomes reported."
    end

    context 'with an outcome' do
      before do
        round.sups.first.update_attributes!(outcome: 'all')
      end

      it 'to_s' do
        expect(stats.to_s).to eq "* in progress: 1 S'Up paired 2 users, 100% positive outcomes and 100% outcomes reported."
      end
    end

    context 'with no paired users in a new sup' do
      let!(:round2) { channel.sup! }

      let(:stats) { described_class.new(round2) }

      it 'to_s' do
        expect(stats.to_s).to eq "* in progress: 0 S'Ups paired 0 users and 2 users missed."
      end
    end
  end

  context 'with a user on vacation' do
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:user3) { Fabricate(:user, channel:, vacation: true) }
    let!(:round) { channel.sup! }
    let!(:stats) { described_class.new(round) }

    it 'to_s' do
      expect(stats.to_s).to eq "* in progress: 1 S'Up paired 2 users, no outcomes reported and 1 user on vacation."
    end
  end

  context 'with a user opted out' do
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:user3) { Fabricate(:user, channel:, opted_in: false) }
    let!(:round) { channel.sup! }
    let!(:stats) { described_class.new(round) }

    it 'to_s' do
      expect(stats.to_s).to eq "* in progress: 1 S'Up paired 2 users, no outcomes reported and 1 user opted out."
    end
  end

  context 'with two users opted out' do
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:, opted_in: false) }
    let!(:user3) { Fabricate(:user, channel:, opted_in: false) }
    let!(:round) { channel.sup! }
    let!(:stats) { described_class.new(round) }

    it 'to_s' do
      expect(stats.to_s).to eq "* in progress: 0 S'Ups paired 0 users, 2 users opted out and 1 user missed."
    end
  end

  context 'with 12 users and 2 sups' do
    before do
      12.times { Fabricate(:user, channel:) }
      2.times { channel.sup! }
    end

    let(:round) { channel.sup! }
    let(:stats) { described_class.new(round) }

    it 'to_s' do
      expect(stats.to_s).to eq "* in progress: 4 S'Ups paired 12 users and no outcomes reported."
    end

    context 'with an outcome' do
      before do
        round.sups.first.update_attributes!(outcome: 'all')
      end

      it 'to_s' do
        expect(stats.to_s).to eq "* in progress: 4 S'Ups paired 12 users, 25% positive outcomes and 25% outcomes reported."
      end
    end
  end
end
