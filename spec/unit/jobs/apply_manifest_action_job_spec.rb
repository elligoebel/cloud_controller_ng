require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe ApplyManifestActionJob, job_context: :worker do
      let(:user) { User.make(admin: true) }
      let(:apply_manifest_action) { instance_double(AppApplyManifest) }
      let(:app) { AppModel.make(name: Sham.guid) }
      let(:parsed_app_manifest) { AppManifestMessage.new({ name: 'blah', instances: 4 }) }

      subject(:job) { ApplyManifestActionJob.new(app.guid, parsed_app_manifest, apply_manifest_action) }

      before do
        allow(apply_manifest_action).to receive(:apply).and_return([])
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:apply_manifest_job)
      end

      it 'calls the delete action' do
        job.perform

        expect(apply_manifest_action).to have_received(:apply).with(app.guid, parsed_app_manifest)
      end

      context 'when the apply manifest action fails' do
        before do
          allow(apply_manifest_action).to receive(:apply).and_raise(StandardError)
        end

        it 'bubbles up the error' do
          expect { job.perform }.to raise_error(StandardError)
        end
      end

      context 'when a ProcessScale::InvalidProcess error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ProcessScale::InvalidProcess, 'maximum instance count exceeded')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /maximum instance count exceeded/)
        end
      end

      context 'when an AppUpdate::InvalidApp error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(AppUpdate::InvalidApp, 'Specified unknown buildpack name')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /unknown buildpack name/)
        end
      end

      context 'when a ProcessUpdate::InvalidProcess error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ProcessUpdate::InvalidProcess, 'Invalid health check type')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid health check type/)
        end
      end

      context 'when an AppPatchEnvironmentVariables::InvalidApp error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(AppPatchEnvironmentVariables::InvalidApp, 'Invalid env varz')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid env varz/)
        end
      end

      describe '#resource_type' do
        it 'returns a display name' do
          expect(job.resource_type).to eq('app')
        end
      end

      describe '#display_name' do
        it 'returns a display name for this action' do
          expect(job.display_name).to eq('app.apply_manifest')
        end
      end

      describe '#resource_guid' do
        it 'returns the given app guid' do
          expect(job.resource_guid).to eq(app.guid)
        end
      end
    end
  end
end
