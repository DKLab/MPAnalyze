   % CM 20131206 code to detect the lines that have more than x saturated
   % pixel and extract set the lines to nan
   % 65535 for images from 
function temp_block=CM_transform_in_NAN(block,threshold_saturation,fraction_of_saturating_pix)

        tac_nan=block>threshold_saturation;
        block_width=size(block,2);
        
        tac_sum = full(sum(sparse(tac_nan),2)); % logical vector CM change to sparse 20140401
        %tac_sum = sum(tac_nan,2); % logical vector CM original before change above
                
        tac_sum=squeeze(tac_sum);
        number_of_saturated_pixel=fraction_of_saturating_pix*(block_width);
        tac_nan=tac_sum>=number_of_saturated_pixel;
        %tac_nan(tac_nan)=nan;
        %tac_nan=double(tac_nan);
        temp_block=double(block);
        tac_nan= squeeze(tac_nan); 
        temp_block(tac_nan,:)=nan;
%         size (block,1)
%         tac_rep=repmat(1,size(block,2));
%         temp_block= block+tac_rep;
end