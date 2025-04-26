require 'spec_helper'

describe SlackSup::Commands::Vacation do
  let(:tuesday) { DateTime.parse('2017/1/3 3:00 PM EST') }
  let(:next_week) { tuesday.beginning_of_day - 1.day + 1.week }

  before do
    Timecop.travel(tuesday)
  end

  context 'team' do
    include_context 'team'

    it 'requires a subscription' do
      expect(message: '@sup vacation').to respond_with_slack_message(team.subscribe_text)
    end
  end

  context 'subscribed team' do
    include_context 'subscribed team'

    context 'dm' do
      context 'as an admin' do
        before do
          allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
        end

        it "shows user's current vacation status" do
          expect(message: '@sup vacation', channel: 'DM').to respond_with_slack_message(
            'You were not found in any channels.'
          )
        end

        it "shows another user's current vacation status" do
          expect(message: '@sup vacation <@some_user>', channel: 'DM').to respond_with_slack_message(
            'User <@some_user> was not found in any channels.'
          )
        end

        context 'with a channel' do
          let!(:channel1) { Fabricate(:channel, team:) }
          let!(:user1) { Fabricate(:user, channel: channel1) }
          let!(:channel2) { Fabricate(:channel, team:) }
          let!(:user2) { Fabricate(:user, channel: channel2, user_id: user1.user_id, vacation_until: Time.now + 2.weeks) }

          it 'shows user not on vacation' do
            expect(message: "@sup vacation <@#{user1.user_id}>", channel: 'DM').to respond_with_slack_message(
              [
                "User #{user1.slack_mention} is not on vacation in #{channel1.slack_mention}.",
                "User #{user1.slack_mention} is on vacation in #{channel2.slack_mention} until Tuesday, January 17, 2017 3:00 pm."
              ].join("\n")
            )
          end
        end
      end

      context 'as a non-admin' do
        before do
          allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
        end

        it 'requires an admin' do
          expect(message: '@sup vacation <@someone>', channel: 'DM').to respond_with_slack_message([
            "Sorry, only <@#{team.activated_user_id}> or a Slack team admin can see or change other users vacations."
          ].join("\n"))
        end

        it 'lists channels' do
          expect(message: '@sup vacation', channel: 'DM').to respond_with_slack_message(
            'You were not found in any channels.'
          )
        end

        context 'on vacation in some channels' do
          let!(:channel1) { Fabricate(:channel, team:) }
          let!(:channel2) { Fabricate(:channel, team:) }
          let!(:channel3) { Fabricate(:channel, team:) }

          context 'self' do
            let!(:user1) { Fabricate(:user, channel: channel1, user_id: 'user') }
            let!(:user2) { Fabricate(:user, channel: channel2, user_id: 'user', vacation_until: next_week) }

            it 'lists channels' do
              expect(message: '@sup vacation', channel: 'DM').to respond_with_slack_message(
                [
                  "You are not on vacation in #{channel1.slack_mention}.",
                  "You are on vacation in #{channel2.slack_mention} until Monday, January 09, 2017 12:00 am."
                ].join("\n")
              )
            end

            it 'vacations in a channel' do
              expect(message: "@sup vacation #{channel1.slack_mention} until next week", channel: 'DM').to respond_with_slack_message(
                "You are now on vacation in #{channel1.slack_mention} until Sunday, January 08, 2017 12:00 am."
              )
            end

            it 'vacations in multiple channels' do
              expect(message: "@sup vacation #{channel1.slack_mention} #{channel2.slack_mention} next month", channel: 'DM').to respond_with_slack_message(
                [
                  "You are now on vacation in #{channel1.slack_mention} until Wednesday, March 01, 2017 12:00 am.",
                  "You are now on vacation in #{channel2.slack_mention} until Wednesday, March 01, 2017 12:00 am."
                ].join("\n")
              )
            end

            it 'shows vacation status in a channel' do
              expect(message: "@sup vacation #{channel2.slack_mention}", channel: 'DM').to respond_with_slack_message(
                "You are on vacation in #{channel2.slack_mention} until Monday, January 09, 2017 12:00 am."
              )
            end

            it 'cancels vacation' do
              expect(message: "@sup vacation #{channel2.slack_mention} cancel", channel: 'DM').to respond_with_slack_message(
                "You are now back from vacation in #{channel2.slack_mention}."
              )
            end

            it 'vacations till different dates in multiple channels' do
              expect(message: "@sup vacation #{channel1.slack_mention} until next year", channel: 'DM').to respond_with_slack_message(
                "You are now on vacation in #{channel1.slack_mention} until Monday, January 01, 2018 12:00 am."
              )
            end

            it 'fails on an unknown channel' do
              expect(message: '@sup vacation <#invalid>', channel: 'DM').to respond_with_slack_message(
                "Sorry, I can't find an existing S'Up channel <#invalid>."
              )
            end

            it 'fails on a channel by name' do
              expect(message: '@sup vacation #invalid', channel: 'DM').to respond_with_slack_message(
                "Sorry, I don't understand who or what #invalid is."
              )
            end
          end

          context 'others' do
            let!(:user1) { Fabricate(:user, channel: channel1) }
            let!(:user2) { Fabricate(:user, channel: channel1) }
            let!(:user3) { Fabricate(:user, channel: channel1) }
            let!(:user1_channel2) { Fabricate(:user, channel: channel2, user_id: user1.user_id, vacation_until: Time.now + 1.week) }
            let!(:user2_channel2) { Fabricate(:user, channel: channel2, user_id: user2.user_id, vacation_until: Time.now + 2.weeks) }

            before do
              allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
            end

            context 'one user' do
              it 'not on vacation in any channel' do
                expect(message: "@sup vacation #{user3.slack_mention}", channel: 'DM').to respond_with_slack_message(
                  "User #{user3.slack_mention} is not on vacation in #{channel1.slack_mention}."
                )
              end

              it 'lists channels on vacation' do
                expect(message: "@sup vacation #{user1.slack_mention}", channel: 'DM').to respond_with_slack_message(
                  [
                    "User #{user1.slack_mention} is not on vacation in #{channel1.slack_mention}.",
                    "User #{user1.slack_mention} is on vacation in #{channel2.slack_mention} until Tuesday, January 10, 2017 3:00 pm."
                  ].join("\n")
                )
              end

              it 'sets vacation in a channel' do
                expect(message: "@sup vacation #{user1.slack_mention} #{channel1.slack_mention} next week", channel: 'DM').to respond_with_slack_message(
                  "User #{user1.slack_mention} is now on vacation in #{channel1.slack_mention} until Sunday, January 15, 2017 12:00 am."
                )
              end

              it 'sets vacation in multiple channels' do
                expect(message: "@sup vacation #{user1.slack_mention} #{channel1.slack_mention} #{channel2.slack_mention} next week", channel: 'DM').to respond_with_slack_message(
                  [
                    "User #{user1.slack_mention} is now on vacation in #{channel1.slack_mention} until Sunday, January 15, 2017 12:00 am.",
                    "User #{user1.slack_mention} is now on vacation in #{channel2.slack_mention} until Sunday, January 15, 2017 12:00 am."
                  ].join("\n")
                )
              end

              it 'changes vacation time' do
                expect(message: "@sup vacation #{user1.slack_mention} #{channel2.slack_mention} until next month", channel: 'DM').to respond_with_slack_message(
                  "User #{user1.slack_mention} is now on vacation in #{channel2.slack_mention} until Wednesday, February 01, 2017 12:00 am."
                )
              end

              it 'cancels vacation' do
                expect(message: "@sup vacation #{user1.slack_mention} #{channel2.slack_mention} cancel", channel: 'DM').to respond_with_slack_message(
                  "User #{user1.slack_mention} is now back from vacation in #{channel2.slack_mention}."
                )
              end

              it 'cgabges vacation in multiple channels' do
                expect(message: "@sup vacation #{user1.slack_mention} #{channel1.slack_mention} #{channel2.slack_mention} next year", channel: 'DM').to respond_with_slack_message(
                  [
                    "User #{user1.slack_mention} is now on vacation in #{channel1.slack_mention} until Tuesday, January 01, 2019 12:00 am.",
                    "User #{user1.slack_mention} is now on vacation in #{channel2.slack_mention} until Tuesday, January 01, 2019 12:00 am."
                  ].join("\n")
                )
              end

              it 'fails on an unknown channel' do
                expect(message: "@sup vacation #{user1.slack_mention} <#invalid>", channel: 'DM').to respond_with_slack_message(
                  "Sorry, I can't find an existing S'Up channel <#invalid>."
                )
              end

              it 'fails in a channel by name' do
                expect(message: "@sup vacation #{user1.slack_mention} #invalid", channel: 'DM').to respond_with_slack_message(
                  "Sorry, I don't understand who or what #invalid is."
                )
              end
            end

            context 'two users' do
              it 'lists channels where the users are on vacation' do
                expect(message: "@sup vacation #{user1.slack_mention} #{user2.slack_mention}", channel: 'DM').to respond_with_slack_message([
                  "User #{user1.slack_mention} is not on vacation in #{channel1.slack_mention}.",
                  "User #{user1.slack_mention} is on vacation in #{channel2.slack_mention} until Tuesday, January 10, 2017 3:00 pm.",
                  "User #{user2.slack_mention} is not on vacation in #{channel1.slack_mention}.",
                  "User #{user2.slack_mention} is on vacation in #{channel2.slack_mention} until Tuesday, January 17, 2017 3:00 pm."
                ].join("\n"))
              end

              it 'sets vacation in a channel' do
                expect(message: "@sup vacation #{user1.slack_mention} #{user2.slack_mention} #{channel1.slack_mention} next week", channel: 'DM').to respond_with_slack_message([
                  "User #{user1.slack_mention} is now on vacation in #{channel1.slack_mention} until Sunday, January 15, 2017 12:00 am.",
                  "User #{user2.slack_mention} is now on vacation in #{channel1.slack_mention} until Sunday, January 15, 2017 12:00 am."
                ].join("\n"))
              end

              it 'sets vacation in multiple channels' do
                expect(message: "@sup vacation out #{user1.slack_mention} #{user2.slack_mention} #{channel1.slack_mention} #{channel2.slack_mention} until tomorrow", channel: 'DM').to respond_with_slack_message([
                  "User #{user1.slack_mention} is now on vacation in #{channel1.slack_mention} until Wednesday, January 04, 2017 12:00 am.",
                  "User #{user1.slack_mention} is now on vacation in #{channel2.slack_mention} until Wednesday, January 04, 2017 12:00 am.",
                  "User #{user2.slack_mention} is now on vacation in #{channel1.slack_mention} until Wednesday, January 04, 2017 12:00 am.",
                  "User #{user2.slack_mention} is now on vacation in #{channel2.slack_mention} until Wednesday, January 04, 2017 12:00 am."
                ].join("\n"))
              end
            end
          end
        end
      end
    end

    context 'channel' do
      include_context 'user'

      before do
        allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
      end

      context 'current user' do
        it 'shows not on vacation' do
          expect(message: '@sup vacation', user: user.user_id).to respond_with_slack_message(
            'You are not on vacation in <#channel>.'
          )
        end

        it 'shows on vacation' do
          user.update_attributes!(vacation_until: Time.now + 2.weeks)
          expect(message: '@sup vacation', user: user.user_id).to respond_with_slack_message(
            'You are on vacation in <#channel> until Tuesday, January 17, 2017 3:00 pm.'
          )
        end

        it 'sets vacation' do
          expect(message: '@sup vacation next week', user: user.user_id).to respond_with_slack_message(
            'You are now on vacation in <#channel> until Sunday, January 15, 2017 12:00 am.'
          )
          expect(user.reload.vacation_until).to eq Time.parse('2017-01-15 00:00:00 -0500')
        end

        it 'cancels vacation' do
          user.update_attributes!(vacation_until: Time.now + 2.weeks)
          expect(message: '@sup vacation cancel', user: user.user_id).to respond_with_slack_message(
            'You are now back from vacation in <#channel>.'
          )
          expect(user.reload.vacation_until).to be_nil
        end

        it 'invalid opt' do
          expect(message: '@sup vacation whatever', user: user.user_id).to respond_with_slack_message(
            "Sorry, I don't understand who or what whatever is."
          )
        end
      end

      context 'another user' do
        context 'as non admin' do
          before do
            allow_any_instance_of(User).to receive(:channel_admin?).and_return(false)
          end

          it 'requires an admin' do
            expect(message: "@sup vacation #{user.slack_mention}").to respond_with_slack_message(
              "Sorry, only #{channel.channel_admins_slack_mentions.or} can see or change other users vacations."
            )
          end
        end

        context 'as admin' do
          before do
            allow_any_instance_of(User).to receive(:channel_admin?).and_return(true)
          end

          it 'sets user vacation' do
            user.update_attributes!(opted_in: false)
            expect(message: "@sup vacation #{user.slack_mention} until next week").to respond_with_slack_message(
              "User #{user.slack_mention} is now on vacation in <#channel> until Sunday, January 08, 2017 12:00 am."
            )
            expect(user.reload.vacation_until).to eq Time.parse('2017-01-08 00:00:00 -0500')
          end

          it 'cancels a user vacation' do
            user.update_attributes!(vacation_until: Time.now + 2.weeks)
            expect(message: "@sup vacation #{user.slack_mention} cancel").to respond_with_slack_message(
              "User #{user.slack_mention} is now back from vacation in <#channel>."
            )
            expect(user.reload.vacation_until).to be_nil
          end

          it 'errors on an invalid user' do
            expect(message: '@sup vacation foobar').to respond_with_slack_message(
              "Sorry, I don't understand who or what foobar is."
            )
          end
        end
      end
    end
  end
end
